import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KingJackpotBiddingClosedDialog extends StatelessWidget {
  final String time;
  final String resultTime;
  final String bidLastTime;

  const KingJackpotBiddingClosedDialog({
    super.key,
    required this.time,
    required this.resultTime,
    required this.bidLastTime,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red cross icon in light pink circle
            CircleAvatar(
              backgroundColor: const Color(0xFFFDE8E8),
              radius: 40,
              child: const Icon(Icons.close, size: 55, color: Color(0xFFE53E3E)),
            ),
            const SizedBox(height: 20),
            Text(
              "Bidding Is Closed For Today",
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE53E3E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  _infoRow("Open Result Time", resultTime),
                  const SizedBox(height: 4),
                  _infoRow("Open Bid Last Time", bidLastTime),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9B233), // Golden yellow
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label :",
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value.isNotEmpty ? value : "--:--",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
