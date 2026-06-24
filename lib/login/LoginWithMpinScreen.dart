import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:new_sara/SetMPIN/SetNewPinScreen.dart';
import 'package:new_sara/components/AppNameBold.dart';

import '../Helper/Toast.dart';
import '../ulits/ColorsR.dart';
import '../ulits/Constents.dart';
import 'HomeScreen/HomeScreen.dart';

class LoginWithMpinScreen extends StatefulWidget {
  const LoginWithMpinScreen({super.key});

  @override
  State<LoginWithMpinScreen> createState() => _LoginWithMpinScreenState();
}

class _LoginWithMpinScreenState extends State<LoginWithMpinScreen> {
  final TextEditingController mpinController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  final storage = GetStorage();
  bool isLoading = false;
  bool isBiometricAvailable = false;
  String? mpinError;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      final biometrics = await auth.getAvailableBiometrics();

      if (isAvailable && isDeviceSupported && biometrics.isNotEmpty) {
        setState(() {
          isBiometricAvailable = true;
        });
      }
    } catch (e) {
      log("Biometric availability check error: $e");
    }
  }

  // Implement the _tryBiometricAuth method with full functionality
  Future<void> _tryBiometricAuth() async {
    try {
      final isAvailable = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      final biometrics = await auth.getAvailableBiometrics();

      if (!isAvailable || !isDeviceSupported || biometrics.isEmpty) {
        _showSnackBar('Biometric authentication not available or supported');
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to verify',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        _validateSavedMpinAndNavigate();
      } else {
        _showSnackBar('Biometric authentication failed');
      }
    } catch (e) {
      log("Biometric error: $e");
      _showSnackBar('Biometric error: $e');
    }
  }

  void _onSetPinPressed() async {
    final mobileNo = storage.read('mobile');
    if (mobileNo == null || mobileNo.toString().isEmpty) {
      popToast("Mobile number not found", 4, Colors.white, ColorsR.appColorRed);
      return;
    }

    // Navigate directly to SetNewPinScreen without sending OTP
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SetNewPinScreen(mobile: mobileNo)),
    );
  }

  /// Login using entered mPIN
  Future<void> _loginWithMpin() async {
    final enteredMpin = mpinController.text.trim();

    setState(() {
      if (enteredMpin.isEmpty) {
        mpinError = 'Please enter your mPIN';
      } else if (enteredMpin.length != 4) {
        mpinError = 'mPIN must be 4 digits';
      } else {
        mpinError = null;
      }
    });

    if (mpinError != null) {
      return;
    }

    // Retrieve registerId and accessToken from GetStorage
    final String? registerId = storage.read('registerId');
    final String? accessToken = storage.read('accessToken');
    final String deviceId = storage.read('deviceId') ?? '';
    final String deviceName = storage.read('deviceName') ?? '';

    log("Register Id: $registerId");
    log("Access Token: $accessToken");

    if (registerId == null || registerId.isEmpty) {
      _showSnackBar('Registration ID not found. Please re-register.');
      return;
    }

    if (accessToken == null || accessToken.isEmpty) {
      _showSnackBar('Access token not found. Please re-login.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = Uri.parse('${Constant.apiEndpoint}verify-mpin');
      final response = await http.post(
        url,
        headers: {
          'deviceId':
              deviceId, // Replace with actual device ID logic if available
          'deviceName':
              deviceName, // Replace with actual device name logic if available
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "registerId": registerId,
          "pinNo": int.tryParse(enteredMpin), // MPIN is expected as an integer
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        log("MPIN Verification Response: $responseData");
        // Assuming the API returns a success status or similar
        if (responseData['status'] == true) {
          // Adjust based on actual API response structure
          _showSnackBar('Login successful!');
          await fetchAndSaveUserDetails(
            registerId,
          ); // Fetch user details after successful MPIN verification
          _navigateToHome();
        } else {
          _showSnackBar(
            responseData['message'] ?? 'Incorrect mPIN. Please try again.',
          );
        }
      } else {
        log(
          "❌ MPIN Verification Failed: ${response.statusCode} => ${response.body}",
        );
        _showSnackBar('Failed to verify mPIN. Please try again later.');
      }
    } catch (e) {
      log("❌ Exception during MPIN verification: $e");
      String friendlyMsg = 'An error occurred. Please try again.';
      if (e.toString().contains('SocketException')) {
        friendlyMsg = 'No internet connection or server unavailable. Please check and try again.';
      }
      _showSnackBar(friendlyMsg);
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Validate saved mPIN (used after biometric success)
  Future<void> _validateSavedMpinAndNavigate() async {
    final String? registerId = storage.read('registerId');
    if (registerId == null || registerId.isEmpty) {
      _showSnackBar('Registration ID not found. Please re-register.');
      return;
    }
    await fetchAndSaveUserDetails(registerId);
    _navigateToHome(); // Biometric passed and mPIN exists
  }

  Future<void> fetchAndSaveUserDetails(String registerId) async {
    final storage = GetStorage();
    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    String accessToken = storage.read('accessToken') ?? '';

    log("Register Id: $registerId");
    log("Access Token: $accessToken");

    try {
      final response = await http.post(
        url,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"registerId": registerId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];
        log("User details: $info");

        // Save individual fields to GetStorage, ensuring walletBalance is stored as String
        storage.write('userId', info['userId']);
        storage.write('fullName', info['fullName']);
        storage.write('emailId', info['emailId']);
        storage.write('mobileNo', info['mobileNo']);
        storage.write('mobileNoEnc', info['mobileNoEnc']);
        // FIX: Convert walletBalance to String before saving
        storage.write('walletBalance', info['walletBalance']?.toString());
        storage.write('profilePicture', info['profilePicture']);
        storage.write('accountStatus', info['accountStatus']);
        storage.write('betStatus', info['betStatus']);

        log("✅ User details saved to GetStorage:");
        info.forEach((key, value) => log('$key: $value'));
      } else {
        print(
          "❌ Failed to fetch user details: ${response.statusCode} => ${response.body}",
        );
      }
    } catch (e) {
      print("❌ Exception fetching user details: $e");
    }
  }

  /// Navigate to Home screen
  void _navigateToHome() {
    storage.write('is_logged_in', true); // Set login status
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  /// Show SnackBar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    mpinController.dispose();
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
                const SizedBox(height: 40),
                const AppNameBold(),
                const SizedBox(height: 60),

                // Label
                Text(
                  'Login With Mpin',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // MPIN Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2), // Light grey background
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                    border: mpinError != null
                        ? Border.all(color: Colors.red.shade400, width: 1)
                        : null,
                  ),
                  child: TextField(
                    controller: mpinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (value) {
                      if (mpinError != null) {
                        setState(() {
                          mpinError = null;
                        });
                      }
                    },
                    cursorColor: const Color(0xFFF9B233),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: "",
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                if (mpinError != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      mpinError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // LOGIN Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginWithMpin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9B233), // Golden/Orange color
                      disabledBackgroundColor: const Color(0xFFF9B233).withAlpha(153),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "LOGIN",
                            style: TextStyle(
                              color: Colors.white, // White text matching the mockup image
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Forgot mPIN
                Center(
                  child: GestureDetector(
                    onTap: _onSetPinPressed,
                    child: const Text(
                      "Forgot mpin ?",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Fingerprint Icon (always displayed)
                Center(
                  child: GestureDetector(
                    onTap: _tryBiometricAuth,
                    child: const Icon(
                      Icons.fingerprint,
                      size: 80,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
