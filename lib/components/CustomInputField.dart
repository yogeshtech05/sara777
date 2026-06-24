import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool showBadge;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Widget? suffixIcon;

  const CustomInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.maxLength,
    this.showBadge = true,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field container with soft shadow and pill shape
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2), // Light grey background
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: errorText != null
                ? Border.all(color: Colors.red.shade400, width: 1)
                : null,
          ),
          child: Row(
            children: [
              if (showBadge) ...[
                // Circular yellow/orange badge containing bank + rupee icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9B233), // Golden brand color
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "₹",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLength: maxLength,
                  enabled: enabled,
                  onChanged: onChanged,
                  cursorColor: const Color(0xFFF9B233),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
              ] else if (suffixIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: suffixIcon!,
                ),
              ],
            ],
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          // Validation error tooltip bubble
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Pointer arrow (pointing to the error icon location)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: CustomPaint(
                    size: const Size(12, 6),
                    painter: _TrianglePainter(color: Colors.red),
                  ),
                ),
                // Tooltip body (black background with a thin red top line)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(4),
                    border: const Border(
                      top: BorderSide(color: Colors.red, width: 3),
                    ),
                  ),
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
