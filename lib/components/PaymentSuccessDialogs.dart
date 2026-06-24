// PaymentSuccessDialog - Modern UI (glass, glow, animated check)
// Drop-in replacement for your existing dialog

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentSuccessDialog extends StatefulWidget {
  final String message;

  /// Optional: callback after Done is pressed (in addition to closing dialog)
  final VoidCallback? onDone;

  /// Optional: auto-close after a duration (null = no auto close)
  final Duration? autoCloseAfter;

  const PaymentSuccessDialog({
    Key? key,
    required this.message,
    this.onDone,
    this.autoCloseAfter,
  }) : super(key: key);

  @override
  State<PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<PaymentSuccessDialog>
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

    // Gentle haptic + start animation
    HapticFeedback.lightImpact();
    _ctrl.forward();

    // Optional auto close
    if (widget.autoCloseAfter != null) {
      Future.delayed(widget.autoCloseAfter!, _handleDone);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleDone() {
    // Persist just like your original code
    GetStorage().write('isPaymentDone', true);

    // Callback (if provided)
    widget.onDone?.call();

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brand-ish greens
    const Color kGreen1 = Color(0xFF22C55E);
    const Color kGreen2 = Color(0xFF16A34A);

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
              // Subtle background glow
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kGreen1.withOpacity(0.08),
                          kGreen2.withOpacity(0.06),
                        ],
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
                        const _SuccessBadge(),
                        const SizedBox(height: 16),

                        Text(
                          'Payment Success',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
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

                        // ✅ Wrap so buttons never overflow/clip
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _GreenGradientButton(
                              label: 'Done',
                              onTap: _handleDone,
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

/// Animated green check with gradient ring + glow
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    const Color kGreen1 = Color(0xFF22C55E);
    const Color kGreen2 = Color(0xFF16A34A);

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
                      color: kGreen1.withOpacity(0.35),
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
                    colors: [kGreen1, kGreen2],
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
              // Check icon
              const Icon(Icons.check_rounded, color: kGreen2, size: 40),
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

/// Gradient green primary button with guaranteed size & Material
class _GreenGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GreenGradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color kGreen1 = Color(0xFF22C55E);
    const Color kGreen2 = Color(0xFF16A34A);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 140, // ✅ fixed width so it always shows nicely
        height: 44, // ✅ fixed height
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kGreen1, kGreen2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3306C167),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
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
    );
  }
}
