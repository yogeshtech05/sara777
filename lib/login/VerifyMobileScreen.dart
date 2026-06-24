import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Helper/Toast.dart';
// Dummy screen imports – replace with your actual ones
import 'package:new_sara/Login/LoginScreen.dart';
import 'package:new_sara/Login/LoginWithMpinScreen.dart';
import 'package:new_sara/ulits/ColorsR.dart';
import 'package:new_sara/ulits/Constents.dart';
import 'package:provider/provider.dart';

import 'HomeScreen/HomeScreen.dart' show HomeScreen;

// -----------------------------
// MODEL
// -----------------------------
class AuthResponse {
  final bool status;
  final String msg;
  final AuthInfo? info;

  AuthResponse({required this.status, required this.msg, this.info});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      status: json['status'] as bool,
      msg: json['msg'] as String,
      info: json.containsKey('info') && json['info'] != null
          ? AuthInfo.fromJson(json['info'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AuthInfo {
  final String? registerId;
  final String? accessToken;

  AuthInfo({this.registerId, this.accessToken});

  factory AuthInfo.fromJson(Map<String, dynamic> json) {
    return AuthInfo(
      registerId: json['registerId'] as String?,
      accessToken: json['accessToken'] as String?,
    );
  }
}

// -----------------------------
// API SERVICE
// -----------------------------
class ApiService {
  final Map<String, String> _baseHeaders = {
    'deviceId': 'qwert',
    'deviceName': 'sm2233',
    'accessStatus': '1',
    'Content-Type': 'application/json',
  };

  Future<AuthResponse> registerWithPassword({
    required String fullName,
    required String mobileNo,
    required String password,
    required String securityPin,
  }) async {
    final Uri url = Uri.parse('${Constant.apiEndpoint}user-register');
    final Map<String, dynamic> requestBody = {
      "fullName": fullName,
      "mobileNo": int.tryParse(mobileNo),
      "password": password,
      "password_confirmation": password,
      "security_pin": int.tryParse(securityPin),
    };

    try {
      final response = await http.post(
        url,
        headers: _baseHeaders,
        body: jsonEncode(requestBody),
      );

      log("📥 Register response: ${response.body}");
      final json = jsonDecode(response.body);
      return AuthResponse.fromJson(json);
    } catch (e) {
      log("❌ Register error: $e");
      return AuthResponse(status: false, msg: "Registration failed.");
    }
  }
}

// -----------------------------
// VIEWMODEL
// -----------------------------
class VerifyMobileViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  final TextEditingController passwordController = TextEditingController();

  bool _isVerifying = false;
  String? _errorMessage;
  String? _successMessage;
  bool _registrationSuccessful = false;

  bool get isVerifying => _isVerifying;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get registrationSuccessful => _registrationSuccessful;

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  Future<void> verifyPassword() async {
    _clearMessages();
    _registrationSuccessful = false;

    final password = passwordController.text.trim();
    if (password.isEmpty) {
      _errorMessage = "Enter a valid password.";
      notifyListeners();
      return;
    }

    final mobile = _storage.read('mobile');
    final name = _storage.read('username') ?? 'User';
    final mpin = _storage.read('user_mpin');

    if (mobile == null || mpin == null || mobile.isEmpty || mpin.isEmpty) {
      _errorMessage = "Missing data. Please restart registration.";
      notifyListeners();
      return;
    }

    _isVerifying = true;
    notifyListeners();

    try {
      final AuthResponse response = await _apiService.registerWithPassword(
        fullName: name,
        mobileNo: mobile,
        password: password,
        securityPin: mpin,
      );

      if (response.status) {
        if (response.info?.accessToken != null &&
            response.info?.registerId != null) {
          _storage.write('accessToken', response.info?.accessToken);
          _storage.write('registerId', response.info?.registerId);
        }

        _successMessage = response.msg;
        _registrationSuccessful = true;
      } else {
        _errorMessage = response.msg;
      }
    } catch (e) {
      _errorMessage = "Error verifying password: ${e.toString()}";
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }
}

// -----------------------------
// VIEW (SCREEN)
// -----------------------------
class VerifyMobileScreen extends StatelessWidget {
  const VerifyMobileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VerifyMobileViewModel(),
      child: const _VerifyMobileScreenContent(),
    );
  }
}

class _VerifyMobileScreenContent extends StatefulWidget {
  const _VerifyMobileScreenContent();

  @override
  State<_VerifyMobileScreenContent> createState() =>
      _VerifyMobileScreenContentState();
}

class _VerifyMobileScreenContentState
    extends State<_VerifyMobileScreenContent> {
  final GetStorage storage = GetStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<VerifyMobileViewModel>(
        context,
        listen: false,
      );

      viewModel.addListener(() {
        if (!mounted) return;

        if (viewModel.errorMessage != null) {
          popToast(
            viewModel.errorMessage!,
            4,
            Colors.white,
            ColorsR.appColorRed,
          );

          if (viewModel.errorMessage!.toLowerCase().contains(
            "already registered",
          )) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EnterMobileScreen()),
            );
          } else if (viewModel.errorMessage!.toLowerCase().contains(
            "login with mpin",
          )) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
            );
          }

          viewModel.clearErrorMessage();
        }

        if (viewModel.successMessage != null) {
          popToast(viewModel.successMessage!, 2, Colors.white, Colors.green);
          viewModel.clearSuccessMessage();

          if (viewModel.registrationSuccessful) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<VerifyMobileViewModel>(context);
    final mobile = storage.read('mobile') ?? 'XXXXXXXXXX';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(width: 6, height: 40, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    "VERIFY YOUR MOBILE \nNUMBER",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Image.asset('assets/images/verification_avatar.png', height: 180),
              const SizedBox(height: 30),
              Text(
                "Password",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your password to\nregister your account",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                mobile.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.orange.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: viewModel.passwordController,
                  keyboardType: TextInputType.text,
                  cursorColor: Colors.orange,
                  obscureText: true,
                  decoration: const InputDecoration(
                    counterText: "",
                    hintText: "Enter Password",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: viewModel.isVerifying ? null : viewModel.verifyPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: viewModel.isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "VERIFY",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}