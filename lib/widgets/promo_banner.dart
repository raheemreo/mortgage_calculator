import 'package:flutter/material.dart';

/// A premium, styled announcement banner for high-visibility Remote Config messages.
class PromoBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;

  const PromoBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D91), Color(0xFF1E40AF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3D91).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Pattern Decoration
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.campaign_rounded,
                size: 100,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon Highlight
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFFFD700), // Gold
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Message Text
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  
                  // Dismiss Button
                  IconButton(
                    onPressed: () {
                      setState(() => _isVisible = false);
                      if (widget.onDismiss != null) widget.onDismiss!();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
