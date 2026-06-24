import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void closeBidDialogue({
  required BuildContext context,
  required String gameName,
  required String openResultTime,
  required String openBidLastTime,
  required String closeResultTime,
  required String closeBidLastTime,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red cross icon in light pink circle
              CircleAvatar(
                backgroundColor: const Color(0xFFFDE8E8),
                radius: 40,
                child: const Icon(Icons.close, size: 50, color: Color(0xFFE53E3E)),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                "Bidding Is Closed For Today",
                style: GoogleFonts.poppins(
                  color: const Color(0xFFC53030),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Game name
              Text(
                gameName.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Timings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildTimeRow("Open Result Time", openResultTime),
                    _buildTimeRow("Open Bid Last Time", openBidLastTime),
                    _buildTimeRow("Close Result Time", closeResultTime),
                    _buildTimeRow("Close Bid Last Time", closeBidLastTime),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9B233), // Golden yellow
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(
                      color: Colors.black, // Black text on yellow button
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildTimeRow(String label, String time) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$label :",
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          time.isNotEmpty ? time : "--:--",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 14.5,
          ),
        ),
      ],
    ),
  );
}
