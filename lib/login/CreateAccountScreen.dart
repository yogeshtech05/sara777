import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_sara/SetMPIN/SetPinScreen.dart';

import '../../../../ulits/ColorsR.dart';
import '../../../Helper/Toast.dart';
import '../components/AppNameBold.dart';
import '../components/CustomButton.dart';
import '../components/CustomInputField.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = GetStorage();

  String mobile = '';
  String? usernameError;
  String? passwordError;

  @override
  void initState() {
    super.initState();
    mobile = storage.read('mobile') ?? '';
  }

  void _onNextPressed() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      usernameError = username.isEmpty ? "Please enter your username" : null;
      if (password.isEmpty) {
        passwordError = "Please enter your password";
      } else if (password.length < 6) {
        passwordError = "Password must be at least 6 characters";
      } else {
        passwordError = null;
      }
    });

    if (usernameError != null || passwordError != null) {
      return;
    }

    storage.write('username', username);
    storage.write('password', password);
    storage.write('mobile', mobile);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SetPinScreen()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
                            'CREATE YOUR NEW',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF555555), // Dark grey
                              height: 1.2,
                            ),
                          ),
                          Text(
                            'ACCOUNT',
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
                const AppNameBold(),
                const SizedBox(height: 50),
                
                // Username field
                CustomInputField(
                  controller: _usernameController,
                  hintText: 'Enter username',
                  errorText: usernameError,
                  showBadge: true,
                  onChanged: (value) {
                    if (usernameError != null) {
                      setState(() {
                        usernameError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                
                // Password field
                CustomInputField(
                  controller: _passwordController,
                  hintText: 'Enter password',
                  obscureText: true,
                  errorText: passwordError,
                  showBadge: true,
                  onChanged: (value) {
                    if (passwordError != null) {
                      setState(() {
                        passwordError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 40),
                
                CustomButton(
                  text: "NEXT",
                  onPressed: _onNextPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}