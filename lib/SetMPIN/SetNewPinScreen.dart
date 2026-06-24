import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../Helper/Toast.dart'; // Assuming this is your popToast
import '../login/HomeScreen/HomeScreen.dart';
import '../ulits/ColorsR.dart';
import '../ulits/Constents.dart';
import '../components/CustomButton.dart';
import '../components/CustomInputField.dart';

class SetNewPinScreen extends StatefulWidget {
  final String mobile;
  const SetNewPinScreen({super.key, required this.mobile});

  @override
  State<SetNewPinScreen> createState() => _SetNewPinScreenState();
}

class _SetNewPinScreenState extends State<SetNewPinScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final storage = GetStorage();
  late final String fcmToken;

  bool isLoading = false;
  String? passwordError;
  String? pinError;

  @override
  void initState() {
    super.initState();
    fcmToken = storage.read('fcmToken') ?? '';
    log("FCM Token: $fcmToken");
  }

  @override
  void dispose() {
    passwordController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> setNewPin() async {
    final mobile = widget.mobile;
    final password = passwordController.text.trim();
    final newPin = pinController.text.trim();

    setState(() {
      passwordError = password.isEmpty ? "Please enter your password" : null;
      pinError = (newPin.isEmpty || newPin.length != 4)
          ? "Please enter a 4-digit PIN"
          : null;
    });

    if (passwordError != null || pinError != null) {
      return;
    }

    setState(() => isLoading = true);

    final body = {
      "mobileNo": int.tryParse(
        mobile,
      ), // Ensure mobile number is parsed as int if API expects it
      "password": password,
      "security_pin": int.tryParse(newPin),
      "fcmToken": fcmToken,
    };

    try {
      final response = await http.post(
        Uri.parse('${Constant.apiEndpoint}reset-mpin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print("📤 Request Body: $body");
      print("📥 Response: ${response.body}");

      final json = jsonDecode(response.body);
      final msg = json['msg'] ?? "Something went wrong";
      final status = json['status'] ?? false;

      if (status == true) {
        final info = json['info'];
        final registerId = info['registerId'];
        final accessToken = info['accessToken'];

        // ✅ Save to GetStorage
        storage.write('user_mpin', newPin);
        storage.write('registerId', registerId);
        storage.write('accessToken', accessToken);

        popToast(msg, 2, Colors.white, Colors.green);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false, // Remove all previous routes
        );
      } else {
        popToast(msg, 4, Colors.white, ColorsR.appColorRed);
      }
    } catch (e) {
      String friendlyMsg = "Something went wrong. Please try again.";
      if (e.toString().contains('SocketException')) {
        friendlyMsg = "No internet connection. Please check and try again.";
      }
      popToast("❌ $friendlyMsg", 4, Colors.white, ColorsR.appColorRed);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9B233), // Golden bar
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SET NEW',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF555555), // Dark grey
                              height: 1.2,
                            ),
                          ),
                          Text(
                            'PIN',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF555555), // Dark grey
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                const Text(
                  "Enter Password",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CustomInputField(
                  controller: passwordController,
                  hintText: "Enter your password",
                  obscureText: true,
                  showBadge: false,
                  errorText: passwordError,
                  onChanged: (value) {
                    if (passwordError != null) {
                      setState(() {
                        passwordError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  "Enter New Security PIN",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CustomInputField(
                  controller: pinController,
                  hintText: "Enter 4 digit PIN",
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  showBadge: false,
                  errorText: pinError,
                  onChanged: (value) {
                    if (pinError != null) {
                      setState(() {
                        pinError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 40),
                CustomButton(
                  text: "SET PIN",
                  onPressed: setNewPin,
                  isLoading: isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}