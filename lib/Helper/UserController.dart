// File: lib/Helper/UserController.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../ulits/Constents.dart';

class UserController extends GetxController {
  final GetStorage _storage = GetStorage();

  // ---------------- Observables ----------------
  var fullName = ''.obs;
  var mobileNo = ''.obs;
  var mobileNoEnc = ''.obs;
  var walletBalance = '0'.obs;
  var accessToken = ''.obs;
  var registerId = ''.obs;
  var accountStatus = false.obs;

  // Fee settings
  var minBid = '0'.obs;
  var minDeposit = '0'.obs;
  var minWithdraw = '0'.obs;
  var withdrawFees = '0'.obs;
  var withdrawOpenTime = ''.obs;
  var withdrawCloseTime = ''.obs;
  var withdrawStatus = false.obs;

  // Payment Details
  var bankName = ''.obs;
  var accountHolderName = ''.obs;
  var accountNumber = ''.obs;
  var ifscCode = ''.obs;
  var accountType = ''.obs;
  var gpayUpiId = ''.obs;
  var gpayQrCode = ''.obs;
  var phonepeUpiId = ''.obs;
  var phonepeQrCode = ''.obs;
  var paytmUpiId = ''.obs;
  var paytmQrCode = ''.obs;
  var bankStatus = false.obs;
  var gpayStatus = false.obs;
  var phonepeStatus = false.obs;
  var paytmStatus = false.obs;
  var selfDepositStatus = false.obs;
  var upiIntentStatus = false.obs;
  var qrStatus = false.obs;
  var upiStatus = false.obs;

  // Contact Details
  var contactMobileNo = ''.obs;
  var contactWhatsappNo = ''.obs;
  var contactAppLink = ''.obs;
  var contactHomepageContent = ''.obs;
  var contactVideoDescription = ''.obs;

  // Meta
  var lastUpdatedAt = Rxn<DateTime>();

  // Device info (initialized once)
  late final String _deviceId;
  late final String _deviceName;

  // ---------------- Internal state ----------------
  Timer? _pollTimer;
  Duration _pollInterval = const Duration(seconds: 4);

  // Concurrency guards
  bool _fetchUserBusy = false;
  bool _fetchFeesBusy = false;
  bool _fetchContactBusy = false;
  bool _fetchPaymentBusy = false;

  // ---------------- Helpers ----------------
  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }
    return false;
  }

  String _asString(dynamic v, [String def = '']) {
    if (v == null) return def;
    return v.toString();
  }

  Map<String, String> _headers({bool withAuth = true}) {
    final h = <String, String>{
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': '1',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (withAuth && accessToken.value.isNotEmpty) {
      h['Authorization'] = 'Bearer ${accessToken.value}';
    }
    return h;
  }

  // ---------------- Lifecycle ----------------
  @override
  void onInit() {
    super.onInit();
    loadInitialData();

    // Workers: token/register change => refresh
    ever<String>(accessToken, (_) => _safeRefreshAfterAuthChange());
    ever<String>(registerId, (_) => _safeRefreshAfterAuthChange());
  }

  @override
  void onReady() {
    super.onReady();
    // One-shot initial refresh
    refreshEverything();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  // ---------------- Load & Headers ----------------
  void loadInitialData() {
    accessToken.value = _asString(_storage.read('accessToken'));
    registerId.value = _asString(_storage.read('registerId'));
    fullName.value = _asString(_storage.read('fullName'));
    mobileNo.value = _asString(_storage.read('mobileNo'));
    mobileNoEnc.value = _asString(_storage.read('mobileNoEnc'));
    walletBalance.value = _asString(_storage.read('walletBalance'), '0');
    accountStatus.value = _asBool(_storage.read('accountStatus'));

    // Device info (once) — fallbacks if storage empty
    _deviceId = _asString(_storage.read('deviceId'), 'qwert');
    _deviceName = _asString(_storage.read('deviceName'), 'sm2233');

    // Fee settings
    minBid.value = _asString(_storage.read('minBid'), '0');
    minDeposit.value = _asString(_storage.read('minDeposit'), '0');
    minWithdraw.value = _asString(_storage.read('minWithdraw'), '0');
    withdrawFees.value = _asString(_storage.read('withdrawFees'), '0');
    withdrawOpenTime.value = _asString(_storage.read('withdrawOpenTime'));
    withdrawCloseTime.value = _asString(_storage.read('withdrawCloseTime'));
    withdrawStatus.value = _asBool(_storage.read('withdrawStatus'));
  }

  // ---------------- Public: Live Refresh API ----------------

  /// One-shot refresh everything important in parallel
  Future<void> refreshEverything() async {
    if (registerId.value.isEmpty || accessToken.value.isEmpty) {
      log('ℹ️ refreshEverything skipped (missing auth)');
      return;
    }
    await Future.wait([
      fetchAndUpdateUserDetails(),
      fetchAndUpdateFeeSettings(),
      fetchPaymentDetails(),
      fetchAndUpdateContactDetails(),
    ]);
    lastUpdatedAt.value = DateTime.now();
  }

  /// Start periodic polling (wallet + fees + payment)
  void startLivePolling({Duration interval = const Duration(seconds: 4)}) {
    _pollInterval = interval;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      await fetchAndUpdateUserDetails();
      // Lightweight cadence: fees/payment can be slower
      if (DateTime.now()
          .difference(lastUpdatedAt.value ?? DateTime(2000))
          .inSeconds >
          30) {
        await fetchAndUpdateFeeSettings();
        await fetchPaymentDetails();
        lastUpdatedAt.value = DateTime.now();
      }
    });
    log('▶️ Live polling started every ${_pollInterval.inSeconds}s');
  }

  /// Stop periodic polling
  void stopLivePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    log('⏹ Live polling stopped');
  }

  // ---------------- Contact Details ----------------
  Future<void> fetchAndUpdateContactDetails() async {
    if (_fetchContactBusy) return;
    if (accessToken.value.isEmpty) {
      log('❌ Access Token missing. Cannot fetch contact details.');
      return;
    }
    _fetchContactBusy = true;

    final url = Uri.parse('${Constant.apiEndpoint}contact-detail');

    try {
      final response = await http.get(url, headers: _headers(withAuth: true));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        log(
          '✅ Contact Details Response:\n${const JsonEncoder.withIndent('  ').convert(data)}',
        );

        final contactInfo = data['info']?['contactInfo'];
        final videosInfo = data['info']?['videosInfo'];

        if (contactInfo == null || videosInfo == null) {
          log('❌ contactInfo or videosInfo is null in response.');
          return;
        }

        // Save to GetStorage
        _storage.write('mobileNoContact', _asString(contactInfo['mobileNo']));
        _storage.write('whatsappNo', _asString(contactInfo['whatsappNo']));
        _storage.write('appLink', _asString(contactInfo['appLink']));
        _storage.write(
          'homepageContent',
          _asString(contactInfo['homepageContent']),
        );
        _storage.write(
          'videoDescription',
          _asString(videosInfo['description']),
        );

        // Update reactive variables
        contactMobileNo.value = _asString(contactInfo['mobileNo']);
        contactWhatsappNo.value = _asString(contactInfo['whatsappNo']);
        contactAppLink.value = _asString(contactInfo['appLink']);
        contactHomepageContent.value = _asString(
          contactInfo['homepageContent'],
        );
        contactVideoDescription.value = _asString(videosInfo['description']);

        log('✅ Contact details updated and saved.');
      } else {
        log('❌ Failed to fetch contact details: ${response.statusCode}');
        log('Response body: ${response.body}');
      }
    } catch (e) {
      log('❌ Exception in fetchAndUpdateContactDetails: $e');
    } finally {
      _fetchContactBusy = false;
    }
  }

  // ---------------- User Details ----------------
  Future<void> fetchAndUpdateUserDetails() async {
    if (_fetchUserBusy) return;
    if (registerId.value.isEmpty || accessToken.value.isEmpty) {
      log('ℹ️ User ID or Access Token missing. Cannot fetch details.');
      return;
    }
    _fetchUserBusy = true;

    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    try {
      final response = await http.post(
        url,
        headers: _headers(withAuth: true),
        body: jsonEncode({"registerId": registerId.value}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];

        if (info != null) {
          // Persist
          _storage.write('userId', info['userId']);
          _storage.write('fullName', info['fullName']);
          _storage.write('mobileNo', info['mobileNo']);
          _storage.write('mobileNoEnc', info['mobileNoEnc']);
          _storage.write('walletBalance', info['walletBalance']);
          _storage.write('accountStatus', info['accountStatus']);

          // Update observables (robust parsing)
          fullName.value = _asString(info['fullName']);
          mobileNo.value = _asString(info['mobileNo']);
          mobileNoEnc.value = _asString(info['mobileNoEnc']);
          walletBalance.value = _asString(info['walletBalance'], '0');
          accountStatus.value = _asBool(info['accountStatus']);

          lastUpdatedAt.value = DateTime.now();
          log("✅ User details updated and UI refreshed.");
        } else {
          log("⚠ user-details: info is null");
        }
      } else {
        log("❌ Failed to fetch user details: ${response.statusCode}");
        log("Response body: ${response.body}");
      }
    } catch (e) {
      log("❌ Exception fetching user details: $e");
    } finally {
      _fetchUserBusy = false;
    }
  }

  // ---------------- Fee Settings ----------------
  Future<void> fetchAndUpdateFeeSettings() async {
    if (_fetchFeesBusy) return;
    if (mobileNo.value.isEmpty || accessToken.value.isEmpty) {
      log('ℹ️ Mobile number or Access Token missing. Cannot fetch fees.');
      return;
    }
    _fetchFeesBusy = true;

    final url = Uri.parse('${Constant.apiEndpoint}fees-settings');
    try {
      final response = await http.get(url, headers: _headers(withAuth: true));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (_asBool(data['status']) && data['info'] != null) {
          final info = data['info'];

          // Persist
          _storage.write('minBid', info['minBid']);
          _storage.write('minDeposit', info['minDeposit']);
          _storage.write('minWithdraw', info['minWithdraw']);
          _storage.write('withdrawFees', info['withdrawFees']);
          _storage.write('withdrawOpenTime', info['withdrawOpenTime']);
          _storage.write('withdrawCloseTime', info['withdrawCloseTime']);
          _storage.write('withdrawStatus', info['withdrawStatus']);

          // Update observables
          minBid.value = _asString(info['minBid'], '0');
          minDeposit.value = _asString(info['minDeposit'], '0');
          minWithdraw.value = _asString(info['minWithdraw'], '0');
          withdrawFees.value = _asString(info['withdrawFees'], '0');
          withdrawOpenTime.value = _asString(info['withdrawOpenTime']);
          withdrawCloseTime.value = _asString(info['withdrawCloseTime']);
          withdrawStatus.value = _asBool(info['withdrawStatus']);

          // New Fields (qrStatus and upiStatus)
          qrStatus.value = _asBool(info['qrStatus']);
          upiStatus.value = _asBool(info['upiStatus']);

          log('✅ Fee settings updated and saved to GetStorage.');
        } else {
          log('⚠ Unexpected fee settings payload: ${response.body}');
        }
      } else {
        log('❌ Fee settings Request failed: ${response.statusCode}');
        log('Response body: ${response.body}');
      }
    } catch (e) {
      log('❌ fetchAndUpdateFeeSettings error: $e');
    } finally {
      _fetchFeesBusy = false;
    }
  }

  // ---------------- Payment Details ----------------
  Future<void> fetchPaymentDetails() async {
    if (_fetchPaymentBusy) return;

    if (accessToken.value.isEmpty) {
      log('ℹ️ Missing accessToken. Cannot fetch payment details.');
      return;
    }

    _fetchPaymentBusy = true;
    final headers = _headers(withAuth: true);
    final uri = Uri.parse('${Constant.apiEndpoint}payment-detail');

    Map<String, dynamic>? _parse(okBody) {
      try {
        final data = jsonDecode(okBody);
        log("✅ Payment Detail: $data");
        if (_asBool(data['status']) && data['info'] != null) {
          return Map<String, dynamic>.from(data['info'] as Map);
        }
        log(
          "⚠ No info found in payment detail. Message: ${data['msg'] ?? data['message']}",
        );
      } catch (e) {
        log('❌ JSON parse error in payment-detail: $e');
      }
      return null;
    }

    void _apply(Map<String, dynamic> info) {
      bankName.value = _asString(info['bankName']);
      accountHolderName.value = _asString(info['accountHolderName']);
      accountNumber.value = _asString(info['accountNumber']);
      ifscCode.value = _asString(info['ifscCode']);
      accountType.value = _asString(
        info['accountType'] ?? info['acccountType'],
      );

      gpayUpiId.value = _asString(info['gpayUpiId']);
      gpayQrCode.value = _asString(info['gpayQrCode']);
      phonepeUpiId.value = _asString(info['phonepeUpiId']);
      phonepeQrCode.value = _asString(info['phonepeQrCode']);
      paytmUpiId.value = _asString(info['paytmUpiId']);
      paytmQrCode.value = _asString(info['paytmQrCode']);

      bankStatus.value = _asBool(info['bankStatus']);
      gpayStatus.value = _asBool(info['gpayStatus']);
      phonepeStatus.value = _asBool(info['phonepeStatus']);
      upiStatus.value = _asBool(info['upiStatus']);
      qrStatus.value = _asBool(info['qrStatus']);
      paytmStatus.value = _asBool(info['paytmStatus']);
      selfDepositStatus.value = _asBool(info['selfDepositStatus']);
      upiIntentStatus.value = _asBool(info['upiIntentStatus']);

      _storage.write('paymentInfo', info);
      log("✅ Payment info updated successfully.");
    }

    try {
      // 1) TRY GET (as per your cURL)
      final getRes = await http.get(uri, headers: headers);
      if (getRes.statusCode == 200) {
        final info = _parse(getRes.body);
        if (info != null) {
          _apply(info);
          return;
        }
      } else {
        log(
          'ℹ️ GET /payment-detail failed: ${getRes.statusCode}  ${getRes.body}',
        );
      }

      // 2) FALLBACK: POST with body (send mobile as STRING, not int)
      final body = jsonEncode({'mobileNo': mobileNo.value});
      final postRes = await http.post(uri, headers: headers, body: body);

      if (postRes.statusCode == 200) {
        final info = _parse(postRes.body);
        if (info != null) {
          _apply(info);
          return;
        }
      } else {
        log(
          '❌ POST /payment-detail failed: ${postRes.statusCode}  ${postRes.body}',
        );
      }
    } catch (e) {
      log('❌ Exception in fetchPaymentDetails: $e');
    } finally {
      _fetchPaymentBusy = false;
    }
  }

  // ---------------- Helpers & Updates ----------------
  void _safeRefreshAfterAuthChange() {
    if (accessToken.value.isNotEmpty && registerId.value.isNotEmpty) {
      refreshEverything();
    }
  }

  // Manual update + persist (optional where relevant)
  void updateName(String name) {
    fullName.value = name;
    _storage.write('fullName', name);
  }

  void updateMobile(String mobile) {
    mobileNo.value = mobile;
    _storage.write('mobileNo', mobile);
  }

  void updateWalletBalance(String balance) {
    walletBalance.value = balance;
    _storage.write('walletBalance', balance);
  }

  void updateMinBid(String value) {
    minBid.value = value;
    _storage.write('minBid', value);
  }

  void updateMinDeposit(String value) {
    minDeposit.value = value;
    _storage.write('minDeposit', value);
  }

  void updateMinWithdraw(String value) {
    minWithdraw.value = value;
    _storage.write('minWithdraw', value);
  }

  void updateWithdrawFees(String value) {
    withdrawFees.value = value;
    _storage.write('withdrawFees', value);
  }

  void updateWithdrawStatus(bool status) {
    withdrawStatus.value = status;
    _storage.write('withdrawStatus', status);
  }

  void updateWithdrawTime(String openTime, String closeTime) {
    withdrawOpenTime.value = openTime;
    withdrawCloseTime.value = closeTime;
    _storage
      ..write('withdrawOpenTime', openTime)
      ..write('withdrawCloseTime', closeTime);
  }

  void updateAccessToken(String token) {
    accessToken.value = token;
    _storage.write('accessToken', token);
    _safeRefreshAfterAuthChange();
  }

  void updateRegisterId(String id) {
    registerId.value = id;
    _storage.write('registerId', id);
    _safeRefreshAfterAuthChange();
  }

  // ---------------- Logout ----------------
  void logout() {
    fullName.value = '';
    mobileNo.value = '';
    mobileNoEnc.value = '';
    walletBalance.value = '0';
    accessToken.value = '';
    registerId.value = '';
    accountStatus.value = false;

    minBid.value = '0';
    minDeposit.value = '0';
    minWithdraw.value = '0';
    withdrawFees.value = '0';
    withdrawOpenTime.value = '';
    withdrawCloseTime.value = '';
    withdrawStatus.value = false;

    _pollTimer?.cancel();
    log("✅ User data cleared for logout.");
  }
}

// // File: lib/Helper/UserController.dart
//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
//
// import '../ulits/Constents.dart';
//
// class UserController extends GetxController {
//   final GetStorage _storage = GetStorage();
//
//   // ---------------- Observables ----------------
//   var fullName = ''.obs;
//   var mobileNo = ''.obs;
//   var mobileNoEnc = ''.obs;
//   var walletBalance = '0'.obs;
//   var accessToken = ''.obs;
//   var registerId = ''.obs;
//   var accountStatus = false.obs;
//
//   // Fee settings
//   var minBid = '0'.obs;
//   var minDeposit = '0'.obs;
//   var minWithdraw = '0'.obs;
//   var withdrawFees = '0'.obs;
//   var withdrawOpenTime = ''.obs;
//   var withdrawCloseTime = ''.obs;
//   var withdrawStatus = false.obs;
//   var qrStatus = false.obs;
//   var upiStatus = false.obs;
//
//   // Payment Details
//   var bankName = ''.obs;
//   var accountHolderName = ''.obs;
//   var accountNumber = ''.obs;
//   var ifscCode = ''.obs;
//   var accountType = ''.obs;
//   var gpayUpiId = ''.obs;
//   var gpayQrCode = ''.obs;
//   var phonepeUpiId = ''.obs;
//   var phonepeQrCode = ''.obs;
//   var paytmUpiId = ''.obs;
//   var paytmQrCode = ''.obs;
//   var bankStatus = false.obs;
//   var gpayStatus = false.obs;
//   var phonepeStatus = false.obs;
//   var paytmStatus = false.obs;
//   var selfDepositStatus = false.obs;
//   var upiIntentStatus = false.obs;
//
//   // Contact Details
//   var contactMobileNo = ''.obs;
//   var contactWhatsappNo = ''.obs;
//   var contactAppLink = ''.obs;
//   var contactHomepageContent = ''.obs;
//   var contactVideoDescription = ''.obs;
//
//   // Meta
//   var lastUpdatedAt = Rxn<DateTime>();
//
//   // Device info (initialized once)
//   late final String _deviceId;
//   late final String _deviceName;
//
//   // ---------------- Internal state ----------------
//   Timer? _pollTimer;
//   Duration _pollInterval = const Duration(seconds: 4);
//
//   // Concurrency guards
//   bool _fetchUserBusy = false;
//   bool _fetchFeesBusy = false;
//   bool _fetchContactBusy = false;
//   bool _fetchPaymentBusy = false;
//
//   // ---------------- Helpers ----------------
//   bool _asBool(dynamic v) {
//     if (v is bool) return v;
//     if (v is num) return v != 0;
//     if (v is String) {
//       final s = v.trim().toLowerCase();
//       return s == 'true' || s == '1' || s == 'yes' || s == 'y';
//     }
//     return false;
//   }
//
//   String _asString(dynamic v, [String def = '']) {
//     if (v == null) return def;
//     return v.toString();
//   }
//
//   Map<String, String> _headers({bool withAuth = true}) {
//     final h = <String, String>{
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': '1',
//       'Content-Type': 'application/json; charset=utf-8',
//       'Accept': 'application/json',
//     };
//     if (withAuth && accessToken.value.isNotEmpty) {
//       h['Authorization'] = 'Bearer ${accessToken.value}';
//     }
//     return h;
//   }
//
//   // ---------------- Lifecycle ----------------
//   @override
//   void onInit() {
//     super.onInit();
//     loadInitialData();
//
//     // Workers: token/register change => refresh
//     ever<String>(accessToken, (_) => _safeRefreshAfterAuthChange());
//     ever<String>(registerId, (_) => _safeRefreshAfterAuthChange());
//   }
//
//   @override
//   void onReady() {
//     super.onReady();
//     // One-shot initial refresh
//     refreshEverything();
//   }
//
//   @override
//   void onClose() {
//     _pollTimer?.cancel();
//     super.onClose();
//   }
//
//   // ---------------- Load & Headers ----------------
//   void loadInitialData() {
//     accessToken.value = _asString(_storage.read('accessToken'));
//     registerId.value = _asString(_storage.read('registerId'));
//     fullName.value = _asString(_storage.read('fullName'));
//     mobileNo.value = _asString(_storage.read('mobileNo'));
//     mobileNoEnc.value = _asString(_storage.read('mobileNoEnc'));
//     walletBalance.value = _asString(_storage.read('walletBalance'), '0');
//     accountStatus.value = _asBool(_storage.read('accountStatus'));
//
//     // Device info (once) — fallbacks if storage empty
//     _deviceId = _asString(_storage.read('deviceId'), 'qwert');
//     _deviceName = _asString(_storage.read('deviceName'), 'sm2233');
//
//     // Fee settings
//     minBid.value = _asString(_storage.read('minBid'), '0');
//     minDeposit.value = _asString(_storage.read('minDeposit'), '0');
//     minWithdraw.value = _asString(_storage.read('minWithdraw'), '0');
//     withdrawFees.value = _asString(_storage.read('withdrawFees'), '0');
//     withdrawOpenTime.value = _asString(_storage.read('withdrawOpenTime'));
//     withdrawCloseTime.value = _asString(_storage.read('withdrawCloseTime'));
//     withdrawStatus.value = _asBool(_storage.read('withdrawStatus'));
//   }
//
//   // ---------------- Public: Live Refresh API ----------------
//
//   /// One-shot refresh everything important in parallel
//   Future<void> refreshEverything() async {
//     if (registerId.value.isEmpty || accessToken.value.isEmpty) {
//       log('ℹ️ refreshEverything skipped (missing auth)');
//       return;
//     }
//     await Future.wait([
//       fetchAndUpdateUserDetails(),
//       fetchAndUpdateFeeSettings(),
//       fetchPaymentDetails(),
//       fetchAndUpdateContactDetails(),
//     ]);
//     lastUpdatedAt.value = DateTime.now();
//   }
//
//   /// Start periodic polling (wallet + fees + payment)
//   void startLivePolling({Duration interval = const Duration(seconds: 4)}) {
//     _pollInterval = interval;
//     _pollTimer?.cancel();
//     _pollTimer = Timer.periodic(_pollInterval, (_) async {
//       await fetchAndUpdateUserDetails();
//       // Lightweight cadence: fees/payment can be slower
//       if (DateTime.now()
//               .difference(lastUpdatedAt.value ?? DateTime(2000))
//               .inSeconds >
//           30) {
//         await fetchAndUpdateFeeSettings();
//         await fetchPaymentDetails();
//         lastUpdatedAt.value = DateTime.now();
//       }
//     });
//     log('▶️ Live polling started every ${_pollInterval.inSeconds}s');
//   }
//
//   /// Stop periodic polling
//   void stopLivePolling() {
//     _pollTimer?.cancel();
//     _pollTimer = null;
//     log('⏹ Live polling stopped');
//   }
//
//   // ---------------- Contact Details ----------------
//   Future<void> fetchAndUpdateContactDetails() async {
//     if (_fetchContactBusy) return;
//     if (accessToken.value.isEmpty) {
//       log('❌ Access Token missing. Cannot fetch contact details.');
//       return;
//     }
//     _fetchContactBusy = true;
//
//     final url = Uri.parse('${Constant.apiEndpoint}contact-detail');
//
//     try {
//       final response = await http.get(url, headers: _headers(withAuth: true));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         log(
//           '✅ Contact Details Response:\n${const JsonEncoder.withIndent('  ').convert(data)}',
//         );
//
//         final contactInfo = data['info']?['contactInfo'];
//         final videosInfo = data['info']?['videosInfo'];
//
//         if (contactInfo == null || videosInfo == null) {
//           log('❌ contactInfo or videosInfo is null in response.');
//           return;
//         }
//
//         // Save to GetStorage
//         _storage.write('mobileNoContact', _asString(contactInfo['mobileNo']));
//         _storage.write('whatsappNo', _asString(contactInfo['whatsappNo']));
//         _storage.write('appLink', _asString(contactInfo['appLink']));
//         _storage.write(
//           'homepageContent',
//           _asString(contactInfo['homepageContent']),
//         );
//         _storage.write(
//           'videoDescription',
//           _asString(videosInfo['description']),
//         );
//
//         // Update reactive variables
//         contactMobileNo.value = _asString(contactInfo['mobileNo']);
//         contactWhatsappNo.value = _asString(contactInfo['whatsappNo']);
//         contactAppLink.value = _asString(contactInfo['appLink']);
//         contactHomepageContent.value = _asString(
//           contactInfo['homepageContent'],
//         );
//         contactVideoDescription.value = _asString(videosInfo['description']);
//
//         log('✅ Contact details updated and saved.');
//       } else {
//         log('❌ Failed to fetch contact details: ${response.statusCode}');
//         log('Response body: ${response.body}');
//       }
//     } catch (e) {
//       log('❌ Exception in fetchAndUpdateContactDetails: $e');
//     } finally {
//       _fetchContactBusy = false;
//     }
//   }
//
//   // ---------------- User Details ----------------
//   Future<void> fetchAndUpdateUserDetails() async {
//     if (_fetchUserBusy) return;
//     if (registerId.value.isEmpty || accessToken.value.isEmpty) {
//       log('ℹ️ User ID or Access Token missing. Cannot fetch details.');
//       return;
//     }
//     _fetchUserBusy = true;
//
//     final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
//     try {
//       final response = await http.post(
//         url,
//         headers: _headers(withAuth: true),
//         body: jsonEncode({"registerId": registerId.value}),
//       );
//
//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final info = responseData['info'];
//
//         if (info != null) {
//           // Persist
//           _storage.write('userId', info['userId']);
//           _storage.write('fullName', info['fullName']);
//           _storage.write('mobileNo', info['mobileNo']);
//           _storage.write('mobileNoEnc', info['mobileNoEnc']);
//           _storage.write('walletBalance', info['walletBalance']);
//           _storage.write('accountStatus', info['accountStatus']);
//
//           // Update observables (robust parsing)
//           fullName.value = _asString(info['fullName']);
//           mobileNo.value = _asString(info['mobileNo']);
//           mobileNoEnc.value = _asString(info['mobileNoEnc']);
//           walletBalance.value = _asString(info['walletBalance'], '0');
//           accountStatus.value = _asBool(info['accountStatus']);
//
//           lastUpdatedAt.value = DateTime.now();
//           log("✅ User details updated and UI refreshed.");
//         } else {
//           log("⚠ user-details: info is null");
//         }
//       } else {
//         log("❌ Failed to fetch user details: ${response.statusCode}");
//         log("Response body: ${response.body}");
//       }
//     } catch (e) {
//       log("❌ Exception fetching user details: $e");
//     } finally {
//       _fetchUserBusy = false;
//     }
//   }
//
//   // ---------------- Fee Settings ----------------
//   Future<void> fetchAndUpdateFeeSettings() async {
//     if (_fetchFeesBusy) return;
//     if (mobileNo.value.isEmpty || accessToken.value.isEmpty) {
//       log('ℹ️ Mobile number or Access Token missing. Cannot fetch fees.');
//       return;
//     }
//     _fetchFeesBusy = true;
//
//     final url = Uri.parse('${Constant.apiEndpoint}fees-settings');
//     try {
//       final response = await http.get(url, headers: _headers(withAuth: true));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (_asBool(data['status']) && data['info'] != null) {
//           final info = data['info'];
//
//           // Persist
//           _storage.write('minBid', info['minBid']);
//           _storage.write('minDeposit', info['minDeposit']);
//           _storage.write('minWithdraw', info['minWithdraw']);
//           _storage.write('withdrawFees', info['withdrawFees']);
//           _storage.write('withdrawOpenTime', info['withdrawOpenTime']);
//           _storage.write('withdrawCloseTime', info['withdrawCloseTime']);
//           _storage.write('withdrawStatus', info['withdrawStatus']);
//
//           // Update observables
//           minBid.value = _asString(info['minBid'], '0');
//           minDeposit.value = _asString(info['minDeposit'], '0');
//           minWithdraw.value = _asString(info['minWithdraw'], '0');
//           withdrawFees.value = _asString(info['withdrawFees'], '0');
//           withdrawOpenTime.value = _asString(info['withdrawOpenTime']);
//           withdrawCloseTime.value = _asString(info['withdrawCloseTime']);
//           withdrawStatus.value = _asBool(info['withdrawStatus']);
//
//           log('✅ Fee settings updated and saved to GetStorage.');
//         } else {
//           log('⚠ Unexpected fee settings payload: ${response.body}');
//         }
//       } else {
//         log('❌ Fee settings Request failed: ${response.statusCode}');
//         log('Response body: ${response.body}');
//       }
//     } catch (e) {
//       log('❌ fetchAndUpdateFeeSettings error: $e');
//     } finally {
//       _fetchFeesBusy = false;
//     }
//   }
//
//   // ---------------- Payment Details ----------------
//   Future<void> fetchPaymentDetails() async {
//     if (_fetchPaymentBusy) return;
//
//     if (accessToken.value.isEmpty) {
//       log('ℹ️ Missing accessToken. Cannot fetch payment details.');
//       return;
//     }
//
//     _fetchPaymentBusy = true;
//     final headers = _headers(withAuth: true);
//     final uri = Uri.parse('${Constant.apiEndpoint}payment-detail');
//
//     Map<String, dynamic>? _parse(okBody) {
//       try {
//         final data = jsonDecode(okBody);
//         log("✅ Payment Detail: $data");
//         if (_asBool(data['status']) && data['info'] != null) {
//           return Map<String, dynamic>.from(data['info'] as Map);
//         }
//         log(
//           "⚠ No info found in payment detail. Message: ${data['msg'] ?? data['message']}",
//         );
//       } catch (e) {
//         log('❌ JSON parse error in payment-detail: $e');
//       }
//       return null;
//     }
//
//     void _apply(Map<String, dynamic> info) {
//       bankName.value = _asString(info['bankName']);
//       accountHolderName.value = _asString(info['accountHolderName']);
//       accountNumber.value = _asString(info['accountNumber']);
//       ifscCode.value = _asString(info['ifscCode']);
//       accountType.value = _asString(
//         info['accountType'] ?? info['acccountType'],
//       );
//
//       gpayUpiId.value = _asString(info['gpayUpiId']);
//       gpayQrCode.value = _asString(info['gpayQrCode']);
//       phonepeUpiId.value = _asString(info['phonepeUpiId']);
//       phonepeQrCode.value = _asString(info['phonepeQrCode']);
//       paytmUpiId.value = _asString(info['paytmUpiId']);
//       paytmQrCode.value = _asString(info['paytmQrCode']);
//
//       bankStatus.value = _asBool(info['bankStatus']);
//       gpayStatus.value = _asBool(info['gpayStatus']);
//       phonepeStatus.value = _asBool(info['phonepeStatus']);
//       qrStatus.value = _asBool(info['qrStatus']);
//       upiStatus.value = _asBool(info['upiStatus']);
//       paytmStatus.value = _asBool(info['paytmStatus']);
//       selfDepositStatus.value = _asBool(info['selfDepositStatus']);
//       upiIntentStatus.value = _asBool(info['upiIntentStatus']);
//
//       _storage.write('paymentInfo', info);
//       log("✅ Payment info updated successfully.");
//     }
//
//     try {
//       // 1) TRY GET (as per your cURL)
//       final getRes = await http.get(uri, headers: headers);
//       if (getRes.statusCode == 200) {
//         final info = _parse(getRes.body);
//         if (info != null) {
//           _apply(info);
//           return;
//         }
//       } else {
//         log(
//           'ℹ️ GET /payment-detail failed: ${getRes.statusCode}  ${getRes.body}',
//         );
//       }
//
//       // 2) FALLBACK: POST with body (send mobile as STRING, not int)
//       final body = jsonEncode({'mobileNo': mobileNo.value});
//       final postRes = await http.post(uri, headers: headers, body: body);
//
//       if (postRes.statusCode == 200) {
//         final info = _parse(postRes.body);
//         if (info != null) {
//           _apply(info);
//           return;
//         }
//       } else {
//         log(
//           '❌ POST /payment-detail failed: ${postRes.statusCode}  ${postRes.body}',
//         );
//       }
//     } catch (e) {
//       log('❌ Exception in fetchPaymentDetails: $e');
//     } finally {
//       _fetchPaymentBusy = false;
//     }
//   }
//
//   // ---------------- Helpers & Updates ----------------
//   void _safeRefreshAfterAuthChange() {
//     if (accessToken.value.isNotEmpty && registerId.value.isNotEmpty) {
//       refreshEverything();
//     }
//   }
//
//   // Manual update + persist (optional where relevant)
//   void updateName(String name) {
//     fullName.value = name;
//     _storage.write('fullName', name);
//   }
//
//   void updateMobile(String mobile) {
//     mobileNo.value = mobile;
//     _storage.write('mobileNo', mobile);
//   }
//
//   void updateWalletBalance(String balance) {
//     walletBalance.value = balance;
//     _storage.write('walletBalance', balance);
//   }
//
//   void updateMinBid(String value) {
//     minBid.value = value;
//     _storage.write('minBid', value);
//   }
//
//   void updateMinDeposit(String value) {
//     minDeposit.value = value;
//     _storage.write('minDeposit', value);
//   }
//
//   void updateMinWithdraw(String value) {
//     minWithdraw.value = value;
//     _storage.write('minWithdraw', value);
//   }
//
//   void updateWithdrawFees(String value) {
//     withdrawFees.value = value;
//     _storage.write('withdrawFees', value);
//   }
//
//   void updateWithdrawStatus(bool status) {
//     withdrawStatus.value = status;
//     _storage.write('withdrawStatus', status);
//   }
//
//   void updateWithdrawTime(String openTime, String closeTime) {
//     withdrawOpenTime.value = openTime;
//     withdrawCloseTime.value = closeTime;
//     _storage
//       ..write('withdrawOpenTime', openTime)
//       ..write('withdrawCloseTime', closeTime);
//   }
//
//   void updateAccessToken(String token) {
//     accessToken.value = token;
//     _storage.write('accessToken', token);
//     _safeRefreshAfterAuthChange();
//   }
//
//   void updateRegisterId(String id) {
//     registerId.value = id;
//     _storage.write('registerId', id);
//     _safeRefreshAfterAuthChange();
//   }
//
//   // ---------------- Logout ----------------
//   void logout() {
//     fullName.value = '';
//     mobileNo.value = '';
//     mobileNoEnc.value = '';
//     walletBalance.value = '0';
//     accessToken.value = '';
//     registerId.value = '';
//     accountStatus.value = false;
//
//     minBid.value = '0';
//     minDeposit.value = '0';
//     minWithdraw.value = '0';
//     withdrawFees.value = '0';
//     withdrawOpenTime.value = '';
//     withdrawCloseTime.value = '';
//     withdrawStatus.value = false;
//
//     _pollTimer?.cancel();
//     log("✅ User data cleared for logout.");
//   }
// }
