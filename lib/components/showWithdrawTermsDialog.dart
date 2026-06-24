import 'package:flutter/material.dart';

Future<void> showWithdrawTermsDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false, // Disable tap to dismiss
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Terms & Conditions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              /// Terms List
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _TermRow("Minimum Withdraw Amount is 1000 ₹"),
                  _TermRow("& Maximum Withdraw Amount is 500000"),
                  _TermRow("Above 5 Lakh You Should Request Us Manually."),
                  _TermRow("Withdraw Request Timing 09:00 AM To 10:00 PM"),
                  _TermRow("Process Time Minimum 1 Hour Maximum 72 Hours."),
                  _TermRow("Withdraw Is Available On All 7 Days Of Week."),
                ],
              ),

              const SizedBox(height: 24),

              /// Accept Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'ACCEPT',
                    style: TextStyle(color: Colors.black),
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

class _TermRow extends StatelessWidget {
  final String text;
  const _TermRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.thumb_up_alt_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
