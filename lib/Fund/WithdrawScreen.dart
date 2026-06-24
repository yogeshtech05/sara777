import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart';


import '../Helper/TranslationHelper.dart';
import '../Helper/UserController.dart';
import '../components/showWithdrawTermsDialog.dart'
    show showWithdrawTermsDialog;

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class WithdrawalMethod {
  static const String googlePay = "Google Pay";
  static const String phonePe = "PhonePe";
  static const String paytm = "Paytm";
  static const String bankAccount = "Bank Account";
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  // --- State ---
  int currentBalance = 0;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController paymentNumberController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController holderNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController ifscCodeController = TextEditingController();

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  String selectedMethod = WithdrawalMethod.googlePay;
  String currentLangCode = GetStorage().read("language")?.toString() ?? "en";
  late final int minimumWithdrawalAmount;
  final Map<String, String> _translationCache = {};

  final String _apiBaseUrl = Constant.apiEndpoint;

  bool _termsShown = false;

  @override
  void initState() {
    super.initState();
    minimumWithdrawalAmount = _readMinWithdrawalFromStorage();
    _loadCurrentBalance();
    // Ensure app settings (times/status) are present
    userController.fetchAndUpdateFeeSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    paymentNumberController.dispose();
    bankNameController.dispose();
    holderNameController.dispose();
    accountNumberController.dispose();
    ifscCodeController.dispose();
    super.dispose();
  }

  // ---- Helpers ----
  int _readMinWithdrawalFromStorage() {
    final v = GetStorage().read("minimumWithdrawalAmount");
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
      final asDouble = double.tryParse(v);
      if (asDouble != null) return asDouble.toInt();
    }
    return 1000;
  }

  void _loadCurrentBalance({bool refreshUI = false}) {
    final dynamic raw = userController.walletBalance.value;
    final double asDouble = (raw is num)
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0.0;
    final int next = asDouble.floor();

    if (refreshUI && mounted) {
      setState(() => currentBalance = next);
    } else {
      currentBalance = next;
    }
  }

  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) return _translationCache[text]!;
    final translated = await TranslationHelper.translate(text, currentLangCode);
    _translationCache[text] = translated;
    return translated;
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
    );
  }

  Widget _buildMethodOption(String method, String logoPath) {
    return Card(
      color: Colors.grey.shade200,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RadioListTile<String>(
        value: method,
        groupValue: selectedMethod,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              selectedMethod = value;
              if (value != WithdrawalMethod.bankAccount) {
                bankNameController.clear();
                holderNameController.clear();
                accountNumberController.clear();
                ifscCodeController.clear();
              } else {
                paymentNumberController.clear();
              }
            });
          }
        },
        secondary: Image.asset(
          logoPath,
          width: 36,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.payment_outlined, size: 36),
        ),
        title: FutureBuilder<String>(
          future: _t(method),
          builder: (_, snap) => Text(
            snap.data ?? method,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        subtitle: FutureBuilder<String>(
          future: _t("Manual approve by Admin"),
          builder: (_, snap) => Text(snap.data ?? "Manual approve by Admin"),
        ),
        activeColor: Colors.orange,
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return FutureBuilder<String>(
      future: _t(hint),
      builder: (_, snap) {
        return TextField(
          controller: controller,
          cursorColor: Colors.orange,
          keyboardType: keyboardType,
          decoration: _buildInputDecoration(snap.data ?? hint),
        );
      },
    );
  }

  Widget _buildBankFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField(bankNameController, "Bank Name"),
        const SizedBox(height: 12),
        _buildTextField(holderNameController, "Account Holder Name"),
        const SizedBox(height: 12),
        _buildTextField(
          accountNumberController,
          "Account Number",
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(ifscCodeController, "IFSC Code"),
      ],
    );
  }

  Widget _buildDynamicFields() {
    String selectedMethodHint;
    switch (selectedMethod) {
      case WithdrawalMethod.googlePay:
        selectedMethodHint = "Enter Google Pay UPI ID";
        break;
      case WithdrawalMethod.phonePe:
        selectedMethodHint = "Enter PhonePe UPI ID";
        break;
      case WithdrawalMethod.paytm:
        selectedMethodHint = "Enter Paytm Number";
        break;
      default:
        selectedMethodHint = "Enter UPI ID/Number";
    }

    return Column(
      children: [
        _buildTextField(
          amountController,
          "Enter Amount",
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        if (selectedMethod != WithdrawalMethod.bankAccount)
          _buildTextField(
            paymentNumberController,
            selectedMethodHint,
            keyboardType: selectedMethod == WithdrawalMethod.paytm
                ? TextInputType.phone
                : TextInputType.text,
          )
        else
          _buildBankFields(),
      ],
    );
  }

  // ----------------- TIME WINDOW LOGIC -----------------

  /// Parse "h:mm AM/PM" to TimeOfDay. Returns null if bad.
  TimeOfDay? _parseAmPm(String s) {
    try {
      final parts = s.trim().split(RegExp(r'\s+'));
      if (parts.length != 2) return null;
      final hm = parts[0].split(':');
      if (hm.length != 2) return null;
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      final isPm = parts[1].toUpperCase().startsWith('P');
      if (h == 12) h = 0; // 12 AM -> 0
      final hour24 = h + (isPm ? 12 : 0);
      return TimeOfDay(hour: hour24, minute: m);
    } catch (_) {
      return null;
    }
  }

  int? _toMinutes(String raw) {
    if (raw.isEmpty) return null;
    var s = raw.trim().toUpperCase();

    // Strip accidental AM/PM if hour already 24h style (e.g. "13:30 PM")
    final badSuffix = s.endsWith(" AM") || s.endsWith(" PM");
    String? suffix;
    if (badSuffix) {
      suffix = s.substring(s.length - 2); // "AM"/"PM"
      s = s.substring(0, s.length - 3).trim(); // remove trailing " AM"/" PM"
    }

    final hm = s.split(':');
    if (hm.length != 2) return null;
    final h = int.tryParse(hm[0]) ?? -1;
    final m = int.tryParse(hm[1]) ?? -1;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;

    int hour24 = h;

    // If there was AM/PM originally and hour <= 12, convert
    if (suffix != null && h >= 0 && h <= 12) {
      if (suffix == "AM") {
        hour24 = (h == 12) ? 0 : h; // 12 AM -> 00
      } else if (suffix == "PM") {
        hour24 = (h == 12) ? 12 : h + 12; // 12 PM -> 12, 1..11 PM -> +12
      }
    }

    return hour24 * 60 + m;
  }

  // Proper 12h text for UI: "1:30 PM" / "11:05 AM"
  String fmtTime12h(String raw) {
    final mins = _toMinutes(raw);
    if (mins == null) return "--:--";
    int h24 = mins ~/ 60, m = mins % 60;
    final isPM = h24 >= 12;
    int h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final mm = m.toString().padLeft(2, '0');
    return "$h12:$mm ${isPM ? 'PM' : 'AM'}";
  }

  /// Equal open/close => CLOSED. Overnight supported.
  bool _isWithinWithdrawWindowNow() {
    final nowDate = DateTime.now();

    // 👉 Sunday check (7 = Sunday)
    if (nowDate.weekday == DateTime.sunday) {
      return false;
    }

    final o = _toMinutes(userController.withdrawOpenTime.value.trim());
    final c = _toMinutes(userController.withdrawCloseTime.value.trim());

    if (!userController.withdrawStatus.value || o == null || c == null)
      return false;

    if (o == c) return false;

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;

    if (o < c) {
      return nowMin >= o && nowMin <= c;
    } else {
      return nowMin >= o || nowMin <= c;
    }
  }

  /// Get formatted window text - shows backend time format as-is
  String _windowText() {
    final o = userController.withdrawOpenTime.value.trim();
    final c = userController.withdrawCloseTime.value.trim();
    if (o.isEmpty || c.isEmpty) return ""; // nothing until data arrives
    return "You can withdraw between ${fmtTime12h(o)} and ${fmtTime12h(c)}.";
  }

  // -----------------------------------------------------

  Future<void> _performWithdrawal() async {
    if (DateTime.now().weekday == DateTime.sunday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Withdrawals are not available on Sunday. Please try tomorrow.")),
      );
      return;
    }
    // Only show timing warning when window is CLOSED
    if (!userController.withdrawStatus.value || !_isWithinWithdrawWindowNow()) {
      final timingLine = _windowText();
      if (timingLine.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(timingLine)));
      }
      return;
    }

    final amountText = amountController.text.trim();
    final paymentDetail = paymentNumberController.text.trim();
    final String? accessToken = GetStorage().read('accessToken')?.toString();
    final String registerId = GetStorage().read('registerId')?.toString() ?? '';

    if (accessToken == null || accessToken.isEmpty || registerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please log in again to continue."))),
      );
      return;
    }

    if (amountText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter an amount."))),
      );
      return;
    }
    final int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter a valid amount."))),
      );
      return;
    }

    if (amount < minimumWithdrawalAmount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t("Minimum withdrawal amount is ₹$minimumWithdrawalAmount."),
          ),
        ),
      );
      return;
    }

    if (amount > currentBalance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Insufficient balance."))),
      );
      return;
    }

    String withdrawType;
    final Map<String, dynamic> requestBody = {
      "registerId": registerId,
      "amount": amount,
    };

    switch (selectedMethod) {
      case WithdrawalMethod.googlePay:
        withdrawType = "googlePay";
        if (paymentDetail.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(await _t("Please enter Google Pay UPI ID.")),
            ),
          );
          return;
        }
        requestBody["upiId"] = paymentDetail;
        break;

      case WithdrawalMethod.phonePe:
        withdrawType = "phonePe";
        if (paymentDetail.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(await _t("Please enter PhonePe UPI ID."))),
          );
          return;
        }
        requestBody["upiId"] = paymentDetail;
        break;

      case WithdrawalMethod.paytm:
        withdrawType = "paytm";
        if (paymentDetail.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(await _t("Please enter Paytm Number."))),
          );
          return;
        }
        requestBody["upiId"] = paymentDetail;
        break;

      case WithdrawalMethod.bankAccount:
        withdrawType = "bank";
        if (bankNameController.text.trim().isEmpty ||
            holderNameController.text.trim().isEmpty ||
            accountNumberController.text.trim().isEmpty ||
            ifscCodeController.text.trim().isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(await _t("Please fill all bank details."))),
          );
          return;
        }
        requestBody["bankName"] = bankNameController.text.trim();
        requestBody["accountHolderName"] = holderNameController.text.trim();
        requestBody["accountNumber"] = accountNumberController.text.trim();
        requestBody["ifscCode"] = ifscCodeController.text.trim();
        break;

      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(await _t("Please select a withdrawal method.")),
          ),
        );
        return;
    }

    requestBody["withdrawType"] = withdrawType;

    log("Withdraw Request Body: ${json.encode(requestBody)}");

    try {
      final response = await http.post(
        Uri.parse('${_apiBaseUrl}withdraw-fund-request'),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      log("Withdraw Response Status: ${response.statusCode}");
      log("Withdraw Response Body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t("Withdrawal request submitted successfully!"),
              ),
            ),
          );
          _clearFields();
          _loadCurrentBalance(refreshUI: true);
        } else {
          final String msg =
          (responseBody['msg']?.toString().trim().isNotEmpty ?? false)
              ? responseBody['msg'].toString()
              : await _t("Withdrawal request failed.");
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(await _t("Server error: ${response.statusCode}")),
          ),
        );
      }
    } catch (e) {
      log("Error during withdrawal request: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("An error occurred: $e"))),
      );
    }
  }

  void _clearFields() {
    amountController.clear();
    paymentNumberController.clear();
    bankNameController.clear();
    holderNameController.clear();
    accountNumberController.clear();
    ifscCodeController.clear();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final timingText = _windowText(); // Backend format (7:30 AM)
      final statusOn = userController.withdrawStatus.value;
      final withinWindow = _isWithinWithdrawWindowNow();

      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.grey.shade200,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Card(
                  elevation: 4,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.black,
                        child: const Center(
                          child: Text(
                            "SARA777",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Image.asset(
                              "assets/images/ic_wallet.png",
                              color: Colors.orange,
                              height: 50,
                              width: 50,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.orange,
                                size: 50,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "\u20B9 $currentBalance",
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                FutureBuilder<String>(
                                  future: _t("Current Balance"),
                                  builder: (_, snap) =>
                                      Text(snap.data ?? "Current Balance"),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Image.asset(
                              'assets/images/mastercard.png',
                              height: 60,
                              width: 60,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.credit_card,
                                color: Colors.grey,
                                size: 60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                /// Show timing card ONLY when window is CLOSED
                //  if (!(statusOn && withinWindow) && timingText.isNotEmpty)
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_clock_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            timingText, // Shows: "You can withdraw between 7:30 AM and 7:30 PM"
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                _buildMethodOption(
                  WithdrawalMethod.googlePay,
                  "assets/images/gpay_deposit.png",
                ),
                _buildMethodOption(
                  WithdrawalMethod.phonePe,
                  "assets/images/phonepe_deposit.png",
                ),
                _buildMethodOption(
                  WithdrawalMethod.paytm,
                  "assets/images/paytm_deposit.png",
                ),
                _buildMethodOption(
                  WithdrawalMethod.bankAccount,
                  "assets/images/bank_emoji.png",
                ),
                const SizedBox(height: 10),
                _buildDynamicFields(),
                const SizedBox(height: 10),

                FutureBuilder<String>(
                  future: _t("SUBMIT"),
                  builder: (_, snap) {
                    return ElevatedButton(
                      onPressed: _performWithdrawal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        snap.data ?? "SUBMIT",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                // FutureBuilder<String>(
                //   future: _t("For withdraw related queries call\nor WhatsApp"),
                //   builder: (_, snapshot1) {
                //     return FutureBuilder<String>(
                //       future: _t("Monday to Sunday \u2022 9:00 AM to 6:00 PM"),
                //       builder: (_, snapshot2) {
                //         return Card(
                //           color: Colors.grey.shade200,
                //           elevation: 2,
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(12),
                //           ),
                //           child: Padding(
                //             padding: const EdgeInsets.all(10),
                //             child: Center(
                //               child: Column(
                //                 mainAxisSize: MainAxisSize.min,
                //                 crossAxisAlignment: CrossAxisAlignment.center,
                //                 children: [
                //                   Text(
                //                     snapshot1.data ??
                //                         "For withdraw related queries call\nor WhatsApp",
                //                     textAlign: TextAlign.center,
                //                     style: const TextStyle(
                //                       fontWeight: FontWeight.bold,
                //                       fontSize: 16,
                //                     ),
                //                   ),
                //                   const SizedBox(height: 8),
                //                   Text(
                //                     snapshot2.data ??
                //                         "Monday to Sunday \n \u2022 9:00 AM to 6:00 PM",
                //                     textAlign: TextAlign.center,
                //                     style: const TextStyle(
                //                       color: Colors.black,
                //                       fontWeight: FontWeight.bold,
                //                       fontSize: 16,
                //                     ),
                //                   ),
                //                 ],
                //               ),
                //             ),
                //           ),
                //         );
                //       },
                //     );
                //   },
                // ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
