import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import '../core/constants/app_colors.dart';
import '../services/gemini_service.dart';
import '../core/constants/theme_extensions.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _gemini = GeminiService();

  // Each map: {'role': 'user'|'assistant', 'text': String}
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  static const List<String> _suggestions = [
    'What mortgage can I afford?',
    'Explain PMI',
    'What is a good DTI ratio?',
    'Compare 15 vs 30-year mortgage',
  ];

  Future<void> _sendMessage([String? prefilled]) async {
    final text = (prefilled ?? _inputController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _gemini.chat(
        history: List.of(_messages)
          ..removeLast(), // exclude the message we just added
        userMessage: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'text': reply});
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text':
              'Sorry, I couldn\'t connect to the AI service. Please check your internet connection and try again.',
        });
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: GradientAppBar(
        title: const Text(
          'AI Financial Assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
            tooltip: 'Clear chat',
            onPressed: () {
              setState(() => _messages.clear());
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.borderColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Disclaimer Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.amber.withValues(alpha: 0.1) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.isDark ? Colors.amber.withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AI estimates only. Not professional financial advice. Consult a licensed advisor for specific situations.',
                          style: TextStyle(
                            color: context.isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Empty state: Suggestion chips
                if (_messages.isEmpty && !_isLoading) ...[
                  Center(
                    child: Icon(
                      Icons.smart_toy_rounded,
                      size: 64,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Ask me anything about\nmortgages & finance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _suggestions
                        .map(
                          (s) => InkWell(
                            onTap: () => _sendMessage(s),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: context.cs.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.borderColor,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Chat messages
                ..._messages.map((msg) {
                  final isUser = msg['role'] == 'user';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isUser) ...[
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0B3893,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy,
                              size: 18,
                              color: Color(0xFF0B3893),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? 'You' : 'AI Assistant',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? const Color(0xFF0B3893)
                                      : (context.isDark ? context.cardColor : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(
                                      isUser ? 16 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      isUser ? 4 : 16,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.textPrimary12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['text']!,
                                  style: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : context.textPrimary,
                                    height: 1.5,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.border,
                            child: Icon(
                              Icons.person,
                              color: context.cs.surface,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                // Typing indicator
                if (_isLoading)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B3893).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.smart_toy,
                          size: 18,
                          color: Color(0xFF0B3893),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDark ? context.cardColor : const Color(0xFFF1F5F9),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TypingDot(delay: 0),
                            SizedBox(width: 4),
                            _TypingDot(delay: 200),
                            SizedBox(width: 4),
                            _TypingDot(delay: 400),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cs.surface.withValues(alpha: 0.95),
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.inputFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: TextField(
                        controller: _inputController,
                        enabled: !_isLoading,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(color: context.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Ask about mortgages...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? (context.isDark ? Colors.white10 : const Color(0xFFCBD5E1))
                          : const Color(0xFF0B3893),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated bouncing dot for the "typing…" indicator.
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0,
      end: -6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}



