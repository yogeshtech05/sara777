import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:developer'; // Added for logging
import 'package:new_sara/login/HomeScreen/HomeScreen.dart'; // Import HomeScreen

import '../../../ulits/ColorsR.dart'; // Ensure this import path is correct
import '../../Helper/Toast.dart'; // Ensure this import path is correct
import '../ulits/Constents.dart'; // Ensure this import path is correct
import '../components/CustomButton.dart';
import '../components/CustomInputField.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController mpinController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final storage = GetStorage();
  bool isLoading = false;
  String? pinError;

  void _onSetPinPressed() async {
    final pin = mpinController.text.trim();

    setState(() {
      if (pin.isEmpty || pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
        pinError = "Please enter a valid 4-digit PIN";
      } else {
        pinError = null;
      }
    });

    if (pinError != null) {
      return;
    }

    final mobile = storage.read('mobile');
    final username = storage.read('username');
    final password = storage.read('password');

    if (mobile == null || username == null || password == null) {
      popToast("Missing registration data", 4, Colors.white, ColorsR.appColorRed);
      return;
    }

    setState(() => isLoading = true);

    try {
      storage.write('user_mpin', pin);

      final Uri url = Uri.parse('${Constant.apiEndpoint}user-register');
      final Map<String, dynamic> requestBody = {
        "fullName": username,
        "mobileNo": int.tryParse(mobile.toString()) ?? mobile,
        "password": password,
        "password_confirmation": password,
        "security_pin": int.tryParse(pin),
      };

      final response = await http.post(
        url,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      log("📥 Register response: ${response.body}");
      final json = jsonDecode(response.body);

      if (json['status'] == true) {
         if (json.containsKey('info') && json['info'] != null) {
           final info = json['info'];
           storage.write('accessToken', info['accessToken']);
           storage.write('registerId', info['registerId']);
         }
         
         popToast(json['msg'] ?? "Registration Successful", 2, Colors.white, Colors.green);
         
         Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        popToast(json['msg'] ?? "Registration failed", 4, Colors.white, ColorsR.appColorRed);
      }

    } catch (e) {
      log("❌ Register error: $e");
      String friendlyMsg = "Something went wrong. Please try again.";
      if (e.toString().contains('SocketException')) {
        friendlyMsg = "No internet connection. Please check and try again.";
      }
      popToast(
        friendlyMsg,
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  @override
  void dispose() {
    mpinController.dispose();
    passwordController.dispose();
    super.dispose();
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
                            'SET YOUR',
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
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/set_mpin_avatar.png',
                    height: 220,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Enter New mPin",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CustomInputField(
                  controller: mpinController,
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
                  onPressed: _onSetPinPressed,
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