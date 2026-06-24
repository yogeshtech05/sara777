import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:new_sara/SetMPIN/SetNewPinScreen.dart';

import '../Helper/Toast.dart';

void showAccountRecoveryDialog(BuildContext context, String mobile) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.all(0),
            title: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'Account Recovery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            content: const Text(
              "Recover your existing account by setting a new MPIN\n\nDo you want to continue?",
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            actions: [
              Center(
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: Colors.orange),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () async {
                          // Navigate directly to SetNewPinScreen without sending OTP
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(); // Close dialog
                          }
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SetNewPinScreen(mobile: mobile),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "RECOVER",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}