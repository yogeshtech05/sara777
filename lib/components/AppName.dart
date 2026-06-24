import 'package:flutter/material.dart';

class AppName extends StatelessWidget {
  final double fontSize;
  final double circleRadius;
  final double lineHeight;
  final double lineWidth;

  const AppName({
    super.key,
    this.fontSize = 24,
    this.circleRadius = 24,
    this.lineHeight = 2,
    this.lineWidth = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: circleRadius * 2,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Orange Circle behind "S"
          CircleAvatar(radius: circleRadius, backgroundColor: Colors.orange),

          // Sara777 Text with Overline
          Padding(
            padding: EdgeInsets.only(left: circleRadius * 0.7),
            child: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'S',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'ara',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '777',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: fontSize * 0.20,
                  left: fontSize * 0.52, // Adjust to align after 'S'
                  child: Container(
                    width: lineWidth,
                    height: lineHeight,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
