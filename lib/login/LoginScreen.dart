import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../../ulits/ColorsR.dart';
import '../../../Components/showAccountRecoveryDialog.dart';
import '../../../Helper/Toast.dart';
import '../ulits/Constents.dart';
import '../SetMPIN/SetNewPinScreen.dart';
import 'CreateAccountScreen.dart';
import 'LoginWithMpinScreen.dart';
import '../components/CustomButton.dart';
import '../components/CustomInputField.dart';

class EnterMobileScreen extends StatefulWidget {
  const EnterMobileScreen({super.key});

  @override
  State<EnterMobileScreen> createState() => _EnterMobileScreenState();
}

class _EnterMobileScreenState extends State<EnterMobileScreen> {
  final TextEditingController mobileController = TextEditingController();
  final storage = GetStorage();

  bool isLoading = false;
  String? mobileError;

  String? validateMobile(String mobile) {
    if (mobile.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  Future<void> _handleNextPressed() async {
    final mobile = mobileController.text.trim();
    final validation = validateMobile(mobile);

    setState(() {
      mobileError = validation;
    });

    if (validation != null) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('${Constant.apiEndpoint}check-mobile'),
            headers: {
              'deviceId': 'qwert', // Replace with actual device ID if available
              'deviceName':
                  'sm2233', // Replace with actual device name if needed
              'accessStatus': '1',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({"mobileNo": int.tryParse(mobile)}),
          )
          .timeout(const Duration(seconds: 10));

      print("Raw response body: ${response.body}");

      final statusCode = response.statusCode;

      if (statusCode == 200) {
        final data = jsonDecode(response.body);
        final statusRaw = data['status'];
        // final msg = data['message']?.toString().trim(); // This variable is not used
        final bool status = statusRaw.toString().toLowerCase() == "true";

        print("API Response: $data");

        storage.write('mobile', mobile);

        if (status) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SetNewPinScreen(mobile: mobile),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
          );
        }
      } else {
        popToast(
          "Server Error: $statusCode",
          4,
          Colors.white,
          ColorsR.appColorRed,
        );
      }
    } on TimeoutException {
      popToast(
        "Request timed out. Please check your internet connection.",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } catch (e, stackTrace) {
      print("Exception: $e");
      print("StackTrace: $stackTrace");
      popToast(
        "Something went wrong. Please try again.",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
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
          child: AutofillGroup(
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
                              'ENTER YOUR MOBILE',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF555555), // Dark grey
                                height: 1.2,
                              ),
                            ),
                            Text(
                              'NUMBER',
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
                      'assets/images/phone_avatar.png',
                      height: 220,
                    ),
                  ),
                  const SizedBox(height: 50),
                  CustomInputField(
                    controller: mobileController,
                    hintText: 'Enter Mobile Number',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    showBadge: true,
                    errorText: mobileError,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (value) {
                      if (mobileError != null) {
                        setState(() {
                          mobileError = null;
                        });
                      }
                      // Sanitize if autofilled full number like "+917007465202"
                      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                      if (digitsOnly.length > 10) {
                        final last10 = digitsOnly.substring(
                          digitsOnly.length - 10,
                        );
                        mobileController.text = last10;
                        mobileController.selection = TextSelection.fromPosition(
                          TextPosition(offset: last10.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                  CustomButton(
                    text: "NEXT",
                    onPressed: _handleNextPressed,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
// import '../../../../ulits/ColorsR.dart';
// import '../../../Components/showAccountRecoveryDialog.dart';
// import '../../../Helper/Toast.dart';
// import '../main.dart';
// import 'CreateAccountScreen.dart';
//
//
// class EnterMobileScreen extends StatefulWidget {
//   const EnterMobileScreen({super.key});
//
//   @override
//   State<EnterMobileScreen> createState() => _EnterMobileScreenState();
// }
//
// class _EnterMobileScreenState extends State<EnterMobileScreen> {
//   final TextEditingController mobileController = TextEditingController();
//   bool isLoading = false;
//
//   String? validateMobile(String mobile) {
//     if (mobile.isEmpty) return 'Mobile number is required';
//     if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
//       return 'Enter a valid 10-digit mobile number';
//     }
//     return null;
//   }
//
//   Future<void> _handleNextPressed() async {
//     final mobile = mobileController.text.trim();
//     final validation = validateMobile(mobile);
//
//     if (validation != null) {
//       popToast(validation, 4, Colors.white, ColorsR.appColorRed);
//       return;
//     }
//
//     setState(() => isLoading = true);
//
//     try {
//       final response = await http
//           .post(
//         Uri.parse('https://app.sara777.co.in/api-check-mobile'),
//         headers: {
//           'Accept': 'application/json',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           "app_key": "HbegvJLeKwSFyAp",
//           "env_type": "Prod",
//           "mobile": mobile,
//         }),
//       )
//           .timeout(const Duration(seconds: 10)); // timeout added
//
//       print("Raw response body: ${response.body}");
//
//       final statusCode = response.statusCode;
//
//       if (statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final statusRaw = data['status'];
//         final msg = data['msg']?.toString().trim();
//         final bool status = statusRaw == true || statusRaw == "true";
//
//         print("API Response: $data");
//
//         storage.write('mobile', mobile);
//
//         if (status) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) =>  CreateAccountScreen()),
//           );
//           // GetPage(
//           //   name: Routes.createAccount,
//           //   page: () => CreateAccountScreen(),
//           // );
//         } else {
//           showAccountRecoveryDialog(context, mobile);
//         }
//       } else {
//         popToast("Server Error: $statusCode", 4, Colors.white, ColorsR.appColorRed);
//       }
//     } on TimeoutException {
//       popToast("Request timed out. Please check your internet connection.", 4, Colors.white, ColorsR.appColorRed);
//     } catch (e, stackTrace) {
//       print("Exception: $e");
//       print("StackTrace: $stackTrace");
//       popToast("Something went wrong. Please try again.", 4, Colors.white, ColorsR.appColorRed);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "ENTER YOUR MOBILE\nNUMBER",
//                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 30),
//               Center(child: Image.asset('assets/mobile_ui.png', height: 200)),
//               const SizedBox(height: 40),
//               TextField(
//                 controller: mobileController,
//                 keyboardType: TextInputType.phone,
//                 maxLength: 10,
//                 decoration: InputDecoration(
//                   counterText: "",
//                   prefixIcon: const Icon(Icons.phone),
//                   hintText: 'Enter your mobile number',
//                   filled: true,
//                   fillColor: Colors.grey[200],
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(32),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 30),
//               SizedBox(
//                 width: double.infinity,
//                 height: 48,
//                 child: ElevatedButton(
//                   onPressed: isLoading ? null : _handleNextPressed,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFF9B233),
//                   ),
//                   child: isLoading
//                       ? const CircularProgressIndicator(color: Colors.black)
//                       : const Text(
//                     "NEXT",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
