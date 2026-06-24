import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BidFailureDialog extends StatelessWidget {
  final String errorMessage;

  const BidFailureDialog({Key? key, this.errorMessage = 'Please try again.'})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(0),
      content: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Bid Placement Failed!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class BidFailureDialog extends StatelessWidget {
//   final String errorMessage;
//
//   const BidFailureDialog({Key? key, this.errorMessage = 'Please try again.'})
//     : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 0,
//       backgroundColor: Colors.transparent,
//       child: Container(
//         padding: const EdgeInsets.all(20.0),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const CircleAvatar(
//               radius: 30,
//               backgroundColor: Colors.red,
//               child: Icon(Icons.close, color: Colors.white, size: 40),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               'Bid Placement Failed!',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.red[700],
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               errorMessage,
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Dismiss this dialog
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 40,
//                   vertical: 12,
//                 ),
//               ),
//               child: Text(
//                 'Dismiss',
//                 style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
