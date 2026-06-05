import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeedbackScreen — Google Forms Integration
// ─────────────────────────────────────────────────────────────────────────────
//
// Submissions go to:
//   https://docs.google.com/forms/d/e/1FAIpQLScnSoFNCrxdLlicFvE9ytE8J5hqif6DtbZS_9h6G8dnrLDJqQ
//
// Entry ID mapping:
//   entry.212942638  → Rating     (1–5 as string)
//   entry.767553553  → Category   (selected chip label)
//   entry.1119963508 → Message    (user feedback text)
//   entry.75363153   → Email      (optional, may be empty)
//
// ─────────────────────────────────────────────────────────────────────────────

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // ── Google Form config ───────────────────────────────────────────────────────

  static const String _formSubmitUrl =
      'https://docs.google.com/forms/d/e/'
      '1FAIpQLScnSoFNCrxdLlicFvE9ytE8J5hqif6DtbZS_9h6G8dnrLDJqQ'
      '/formResponse';

  static const String _entryRating = 'entry.212942638';
  static const String _entryCategory = 'entry.767553553';
  static const String _entryMessage = 'entry.1119963508';
  static const String _entryEmail = 'entry.75363153';

  // ── Form state ───────────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageFocusNode = FocusNode();

  int _starRating = 0;
  String? _selectedCategory;
  bool _isSubmitting = false;

  static const int _maxMessageLength = 500;
  static const int _minMessageLength = 10;
  final List<Map<String, dynamic>> _categories = [
    {'label': 'Bug Report', 'icon': Icons.bug_report_outlined},
    {'label': 'Feature Request', 'icon': Icons.lightbulb_outline},
    {'label': 'General', 'icon': Icons.chat_bubble_outline},
    {'label': 'UI / UX', 'icon': Icons.palette_outlined},
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // ── Submit to Google Forms ────────────────────────────────────────────────────

  Future<void> _submitFeedback() async {
    FocusScope.of(context).unfocus();

    if (_starRating == 0) {
      _showSnackBar('Please select a star rating.');
      return;
    }
    if (_selectedCategory == null) {
      _showSnackBar('Please select a feedback category.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http
          .post(
            Uri.parse(_formSubmitUrl),
            body: {
              _entryRating: _starRating.toString(),
              _entryCategory: _selectedCategory!,
              _entryMessage: _messageController.text.trim(),
              _entryEmail: _emailController.text.trim(),
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      // Google Forms returns 200 or 302 on successful submission
      if (response.statusCode == 200 || response.statusCode == 302) {
        _showSuccessDialog();
      } else {
        _showSnackBar(
          'Submission failed (${response.statusCode}). Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Feedback submission error: $e');
      _showSnackBar(
        'Network error. Please check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _messageController.clear();
    _emailController.clear();
    setState(() {
      _starRating = 0;
      _selectedCategory = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E8449).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF1E8449),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thank You!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback has been submitted successfully. We appreciate you helping us improve the app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                _resetForm();
                Navigator.pop(context); // back to settings
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E8449),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  color: context.cs.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GradientAppBar(
        title: Text(
          'Send Feedback',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Text(
                  'We\'d love to hear from you!',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your feedback helps us make the app better for everyone.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Star Rating ─────────────────────────────────────────
                _buildSectionLabel('How would you rate your experience? *'),
                const SizedBox(height: 12),
                _buildStarRating(),

                const SizedBox(height: 28),

                // ── Category ────────────────────────────────────────────
                _buildSectionLabel('What is your feedback about? *'),
                const SizedBox(height: 12),
                _buildCategoryChips(),

                const SizedBox(height: 28),

                // ── Message ─────────────────────────────────────────────
                _buildSectionLabel('Your Message *'),
                const SizedBox(height: 12),
                _buildMessageField(),

                const SizedBox(height: 20),

                // ── Email (optional) ────────────────────────────────────
                _buildSectionLabel('Email (optional)'),
                const SizedBox(height: 6),
                Text(
                  'Leave your email if you\'d like us to follow up with you.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _buildEmailField(),

                const SizedBox(height: 32),

                // ── Submit ──────────────────────────────────────────────
                _buildSubmitButton(),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildStarRating() {
 List<String> labels = ['Terrible', 'Bad', 'Okay', 'Good', 'Amazing'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _starRating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    star <= _starRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: star <= _starRating
                        ? const Color(0xFFFFC107)
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          if (_starRating > 0) ...[
            const SizedBox(height: 10),
            Text(
              labels[_starRating - 1],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFC107),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat['label'];
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedCategory = cat['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  size: 16,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  cat['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _messageController,
      builder: (context, value, _) {
        final charCount = value.text.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextFormField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: 5,
              maxLength: _maxMessageLength,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => const SizedBox.shrink(),
              decoration: InputDecoration(
                hintText: 'Describe your feedback in detail...',
                hintStyle: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.inter(fontSize: 14),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your feedback message.';
                }
                if (value.trim().length < _minMessageLength) {
                  return 'Message must be at least $_minMessageLength characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Text(
              '$charCount / $_maxMessageLength',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: charCount >= _maxMessageLength
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: 'you@example.com',
        hintStyle: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: GoogleFonts.inter(fontSize: 14),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Please enter a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.cs.surface,
                ),
              )
            : Text(
                'Submit Feedback',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
