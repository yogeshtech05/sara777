import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedMessageBar extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback?
  onDismissed; // Optional callback when message is dismissed

  const AnimatedMessageBar({
    Key? key,
    required this.message,
    this.isError = false,
    this.onDismissed,
  }) : super(key: key);

  @override
  _AnimatedMessageBarState createState() => _AnimatedMessageBarState();
}

class _AnimatedMessageBarState extends State<AnimatedMessageBar> {
  double _height = 0.0;
  Timer? _visibilityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBar();
    });
  }

  void _showBar() {
    if (!mounted) return;
    setState(() {
      _height = 48.0; // Desired visible height of the message bar
    });

    _visibilityTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _height = 0.0; // Collapse height to hide
      });
      // After animation, call onDismissed callback if provided
      Timer(const Duration(milliseconds: 300), () {
        // Match AnimatedContainer duration
        if (mounted && widget.onDismissed != null) {
          widget.onDismissed!();
        }
      });
    });
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: _height,
      duration: const Duration(milliseconds: 300), // Animation speed
      curve: Curves.easeInOut, // Smooth animation curve
      color: widget.isError
          ? Colors.red
          : Colors.green, // Red for error, Green for success
      alignment: Alignment.center,
      child:
          _height >
              0.0 // Only show content when height is not 0
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(), // Hide content when collapsed
    );
  }
}
