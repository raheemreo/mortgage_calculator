import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndPrintSchedule({
    required double principal,
    required double interestRate,
    required int years,
    required List<Map<String, dynamic>> schedule,
    bool isMonthly = true,
  }) async {
    final pdf = pw.Document();
    final NumberFormat currencyFormat = NumberFormat.simpleCurrency();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Amortization Schedule',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Loan Summary',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Principal:'),
                      pw.Text(
                        currencyFormat.format(principal),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Interest Rate:'),
                      pw.Text(
                        '$interestRate%',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Loan Term:'),
                      pw.Text(
                        '$years Years',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: isMonthly
                  ? ['Month', 'Principal', 'Interest', 'Balance']
                  : ['Year', 'Principal', 'Interest', 'Balance'],
              data: schedule.map((item) {
                return [
                  isMonthly ? item['month'] : item['year'],
                  currencyFormat.format(item['principal']),
                  currencyFormat.format(item['interest']),
                  currencyFormat.format(item['balance']),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {0: pw.Alignment.centerLeft},
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Amortization_Schedule.pdf',
    );
  }
}
