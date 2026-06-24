// Modern Payment Failure Dialog (glass, glow, animated cross)
// Drop-in replacement keeping the original class name.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentFailtureDialog extends StatefulWidget {
  /// Dynamic error message
  final String message;

  /// Optional: callback after Dismiss is pressed
  final VoidCallback? onDismiss;

  /// Optional: auto-close after a duration (null = no auto close)
  final Duration? autoCloseAfter;

  const PaymentFailtureDialog({
    Key? key,
    required this.message,
    this.onDismiss,
    this.autoCloseAfter,
  }) : super(key: key);

  @override
  State<PaymentFailtureDialog> createState() => _PaymentFailtureDialogState();
}

class _PaymentFailtureDialogState extends State<PaymentFailtureDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleIn;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleIn = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Haptic + start animation
    HapticFeedback.mediumImpact();
    _ctrl.forward();

    if (widget.autoCloseAfter != null) {
      Future.delayed(widget.autoCloseAfter!, _handleDismiss);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    widget.onDismiss?.call();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brand-ish reds
    const Color kRed1 = Color(0xFFEF4444);
    const Color kRed2 = Color(0xFFDC2626);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ScaleTransition(
        scale: _scaleIn,
        child: FadeTransition(
          opacity: _fadeIn,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Subtle red glow backdrop
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kRed1.withOpacity(0.08),
                          kRed2.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              // Glass card
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _FailureBadge(),
                        const SizedBox(height: 16),

                        Text(
                          'Payment Failed',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7F1D1D),
                          ),
                        ),
                        const SizedBox(height: 8),

                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              height: 1.5,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ✅ Wrap so buttons never overflow & always show
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _RedGradientButton(
                              label: 'Dismiss',
                              onTap: _handleDismiss,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated red cross with gradient ring + glow
class _FailureBadge extends StatelessWidget {
  const _FailureBadge();

  @override
  Widget build(BuildContext context) {
    const Color kRed1 = Color(0xFFEF4444);
    const Color kRed2 = Color(0xFFDC2626);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kRed1.withOpacity(0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Gradient ring
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kRed1, kRed2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Inner white circle
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              // Cross icon
              const Icon(Icons.close_rounded, color: kRed2, size: 40),
            ],
          ),
        );
      },
    );
  }
}

/// Soft round icon button with proper Material for Ink splash
class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _SoftIconButton({
    required this.icon,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFE2E8F0).withOpacity(0.7);
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Ink(
          decoration: ShapeDecoration(color: bg, shape: const CircleBorder()),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.close_rounded, color: Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient red primary button with guaranteed size & Material
class _RedGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RedGradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color kRed1 = Color(0xFFEF4444);
    const Color kRed2 = Color(0xFFDC2626);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 140, // ✅ fixed min width so text never gets cramped
        minHeight: 44, // ✅ fixed min height so it never clips vertically
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kRed1, kRed2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33EF4444),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Center(
                // ✅ FittedBox ensures long/large text scales to fit
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    softWrap: false,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
