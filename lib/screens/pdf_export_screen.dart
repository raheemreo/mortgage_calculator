import 'dart:io';
import '../widgets/gradient_app_bar.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/affordability_model.dart';
import '../core/constants/theme_extensions.dart';

class PdfExportScreen extends StatefulWidget {
  final SavedAffordabilityCalculation calculation;
  final List<Map<String, double>> schedule;

  const PdfExportScreen({
    super.key,
    required this.calculation,
    required this.schedule,
  });

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  Color get primary => context.cs.primary;
  Color get primaryContainer => context.cs.primary;
  Color get onSurface => context.textPrimary;
  Color get onSurfaceVariant => context.textSecondary;
  Color get errorColor => context.isDarkMode ? const Color(0xFFFF6B6B) : const Color(0xFFBA1A1A);
  Color get errorContainer => context.isDarkMode ? const Color(0xFFBA1A1A).withValues(alpha: 0.25) : const Color(0xFFFFDAD6);
  Color get outlineVariant => context.borderColor;
  Color get surfaceContainerLowest => context.cardColor;
  Color get surfaceContainerHigh => context.inputFill;
  Color get surface => context.pageBackground;

  bool _isGenerating = false;

  NumberFormat get _currency => context.currencyFormat(decimalDigits: 2);
  NumberFormat get _currencyInt => context.currencyFormat(decimalDigits: 0);
  final _dateFormat = DateFormat('MMMM dd, yyyy');

  // ── PDF generation ─────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf() async {
    final doc = pw.Document(
      title: 'Amortization Schedule - ${widget.calculation.name}',
      author: 'Mortgage Calculator App',
    );

    final interestRate = widget.calculation.input.interestRate;
    final loanTerm = widget.calculation.input.loanTerm;
    final monthlyPayment =
        widget.calculation.result.breakdown.principalAndInterest;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Mortgage Calculator - PDF Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated via Mortgage Calculator - PITI & DTI',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DATE',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _dateFormat.format(widget.calculation.date),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 2, color: PdfColors.black),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '© ${DateTime.now().year} Mortgage Calculator - PITI & DTI',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Loan summary
            pw.Container(
              padding: const pw.EdgeInsets.only(left: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(
                    color: PdfColor.fromInt(0xFF0037B1),
                    width: 4,
                  ),
                ),
              ),
              child: pw.Text(
                'LOAN SUMMARY',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _pdfStat(
                    'PROPERTY VALUE',
                    _currencyInt.format(widget.calculation.result.maxHomePrice),
                  ),
                ),
                pw.Expanded(
                  child: _pdfStat(
                    'INTEREST RATE',
                    '${interestRate.toStringAsFixed(2)}% Fixed',
                  ),
                ),
                pw.Expanded(child: _pdfStat('LOAN TERM', '$loanTerm Years')),
                pw.Expanded(
                  child: _pdfStat(
                    'MONTHLY P&I',
                    _currency.format(monthlyPayment),
                    color: const PdfColor.fromInt(0xFF0037B1),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Payment schedule table header
            pw.Container(
              padding: const pw.EdgeInsets.only(left: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(
                    color: PdfColor.fromInt(0xFF0037B1),
                    width: 4,
                  ),
                ),
              ),
              child: pw.Text(
                'PAYMENT SCHEDULE',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // Table
            pw.Table(
              border: pw.TableBorder(
                bottom: const pw.BorderSide(color: PdfColors.black, width: 1),
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                    ),
                  ),
                  children: [
                    _pdfCell('NO.', isHeader: true),
                    _pdfCell('PRINCIPAL', isHeader: true),
                    _pdfCell('INTEREST', isHeader: true),
                    _pdfCell(
                      'BALANCE',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                // Data rows
                ...widget.schedule.map((row) {
                  return pw.TableRow(
                    children: [
                      _pdfCell(
                        row['month']!.toInt().toString().padLeft(2, '0'),
                      ),
                      _pdfCell(_currency.format(row['principal']!)),
                      _pdfCell(_currency.format(row['interest']!)),
                      _pdfCell(
                        _currency.format(row['balance']!),
                        isBold: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfStat(String label, String value, {PdfColor? color}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 9,
          fontWeight: isHeader || isBold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.black,
        ),
      ),
    );
  }

  // ── Download PDF ────────────────────────────────────────────────────────────
  Future<void> _downloadPdf() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generatePdf();
      final sanitizedName = widget.calculation.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Amortization_$sanitizedName.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Share PDF ───────────────────────────────────────────────────────────────
  Future<void> _sharePdf() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generatePdf();
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = widget.calculation.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
      final fileName = 'Amortization_$sanitizedName.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Amortization Schedule - ${widget.calculation.name}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _dateFormat.format(widget.calculation.date);
    final sanitizedName = widget.calculation.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
    final fileName = 'Amortization_Schedule_$sanitizedName.pdf';

    return Scaffold(
      backgroundColor: surface,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  // File info card
                  _buildFileInfoCard(fileName),
                  const SizedBox(height: 20),
                  // PDF preview
                  _buildPdfPreview(dateStr),
                ],
              ),
            ),
          ),
          // Fixed bottom action bar
          _buildActionBar(),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return GradientAppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Amortization Schedule',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── File info card ─────────────────────────────────────────────────────────
  Widget _buildFileInfoCard(String fileName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: errorColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'PDF DOCUMENT • ~250 KB',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'READY',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PDF preview ────────────────────────────────────────────────────────────
  Widget _buildPdfPreview(String dateStr) {
    final rows = widget.schedule.take(7).toList();
    final totalPages = (widget.schedule.length / 30).ceil();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1 / 1.414,
        child: Container(
          decoration: BoxDecoration(
            // Paper always white — this IS a document preview.
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Internal PDF header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mortgage Ledger',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'Generated via Mortgage Calculator - PITI, DTI',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'DATE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 9, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(thickness: 2, color: Colors.black),
            const SizedBox(height: 12),
            // Loan summary
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: primary, width: 4)),
              ),
              child: const Text(
                'LOAN SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _previewStat(
                    'PROPERTY VALUE',
                    _currencyInt.format(widget.calculation.result.maxHomePrice),
                  ),
                ),
                Expanded(
                  child: _previewStat(
                    'INTEREST RATE',
                    '${widget.calculation.input.interestRate.toStringAsFixed(2)}% Fixed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _previewStat(
                    'LOAN TERM',
                    '${widget.calculation.input.loanTerm} Years',
                  ),
                ),
                Expanded(
                  child: _previewStat(
                    'MONTHLY P&I',
                    _currency.format(
                      widget.calculation.result.breakdown.principalAndInterest,
                    ),
                    valueColor: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Schedule table
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: primary, width: 4)),
              ),
              child: const Text(
                'PAYMENT SCHEDULE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Table header
            const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'NO.',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PRINCIPAL',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'INTEREST',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'BALANCE',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2, color: Colors.black, height: 10),
            ...rows.asMap().entries.map((e) {
              final row = e.value;
              final opacity = e.key >= 5 ? 0.3 : 1.0;
              return Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          row['month']!.toInt().toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currency.format(row['principal']!),
                          style: const TextStyle(fontSize: 8),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currency.format(row['interest']!),
                          style: const TextStyle(fontSize: 8),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currency.format(row['balance']!),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '... Continued for ${widget.schedule.length} monthly payments ...',
                style: const TextStyle(
                  fontSize: 8,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
            const Spacer(),
            const Divider(color: Colors.grey, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© ${DateTime.now().year} Mortgage Calculator - PITI, DTI',
                  style: const TextStyle(fontSize: 7, color: Colors.grey),
                ),
                Text(
                  'Page 1 of $totalPages',
                  style: const TextStyle(fontSize: 7, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _previewStat(String label, String value, {Color? valueColor}) {
    // These live INSIDE the white paper preview — always dark text on white.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9E9E9E),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF212121),
          ),
        ),
      ],
    );
  }

  // ── Fixed action bar ───────────────────────────────────────────────────────
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: outlineVariant.withValues(alpha: 0.25)),
        ),
        boxShadow: [
          BoxShadow(
            color: onSurface.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isGenerating ? null : _sharePdf,
              icon: _isGenerating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onSurfaceVariant,
                      ),
                    )
                  : const Icon(Icons.share_rounded),
              label: const Text(
                'Share',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurfaceVariant,
                side: BorderSide(color: outlineVariant.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _downloadPdf,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text(
                'Download PDF',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryContainer,
                foregroundColor: Colors.white,
                disabledBackgroundColor: outlineVariant.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 6,
                shadowColor: primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
