import 'package:flutter/material.dart';

class AppNameBold extends StatelessWidget {
  const AppNameBold({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Orange circle behind "S"
          const CircleAvatar(radius: 48, backgroundColor: Colors.orange),

          // "Sara777" text with overline above "ara"
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'S',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'ara',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '777',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                // Bold line above "ara"
                Positioned(
                  top: 12.7,
                  left: 25, // start right after "S"
                  child: Container(
                    width: 65, // approximate width for "ara"
                    height: 4,
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
