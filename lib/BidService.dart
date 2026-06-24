import 'dart:convert';
import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart';

class BidService {
  final GetStorage _storage;
  BidService(this._storage);

  Future<Map<String, dynamic>> placeFinalBids({
    required String gameName,
    required String accessToken,
    required String registerId,
    required String deviceId,
    required String deviceName,
    required bool accountStatus,
    required Map<String, String> bidAmounts, // key -> points
    required String
    selectedGameType, // e.g. OPEN / CLOSE / FULLSANGAM / HALF BRACKET / FULL BRACKET
    required int gameId,
    required String gameType, // e.g. singlePana, fullSangam, etc.
    required int totalBidAmount,
  }) async {
    final String apiUrl = Constant.apiEndpoint.endsWith('/')
        ? '${Constant.apiEndpoint}place-bid'
        : '${Constant.apiEndpoint}/place-bid';

    if (accessToken.isEmpty || registerId.isEmpty) {
      return {
        'status': false,
        'msg': 'Authentication error. Please log in again.',
      };
    }

    final headers = {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final String mode = selectedGameType.toUpperCase().trim();

    // ---- robust gameType normalization (no behavior change, just safer matching)
    final String gtRaw = gameType.toLowerCase().trim();
    final String gt = gtRaw.replaceAll(
      RegExp(r'[\s_\-]'),
      '',
    ); // e.g. "double_pana" -> "doublepana"

    bool _isPanaGame() {
      // covers single/double/triple pana + common aliases like *patti
      return gt.contains('singlepana') ||
          gt.contains('doublepana') ||
          gt.contains('triplepana') ||
          gt.contains('singlepatti') ||
          gt.contains('doublepatti') ||
          gt.contains('triplepatti');
    }

    bool _isSangam() => gt.contains('sangam');
    bool _isBracket() => mode.contains('BRACKET');

    /// Build the bid payload correctly for each game shape.
    final List<Map<String, dynamic>> bidPayloadList = [];

    bidAmounts.forEach((rawKey, amountStr) {
      final int bidAmount = int.tryParse(amountStr) ?? 0;
      if (bidAmount <= 0) return;

      final String key = (rawKey ?? '').trim();
      if (key.isEmpty) return;

      String pana = '';
      String digit = '';

      if (_isBracket()) {
        // Red/Full/Half Bracket -> single value key (digit/jodi), server expects it in "digit"
        digit = key;
        pana = '';
      } else if (_isSangam()) {
        // Sangam types come as "A-B"
        final parts = key.split('-').map((e) => e.trim()).toList();
        if (parts.length != 2 || parts.any((p) => p.isEmpty)) {
          log('Skipping malformed Sangam key: $key', name: 'BidAPI');
          return;
        }
        if (mode.contains('FULL')) {
          // FullSangam: openPanna-closePanna
          pana = parts[0];
          digit = parts[1];
        } else if (mode.contains('OPEN')) {
          // Half Sangam A: openDigit-closePanna
          digit = parts[0];
          pana = parts[1];
        } else if (mode.contains('CLOSE')) {
          // Half Sangam B: openPanna-closeDigit
          pana = parts[0];
          digit = parts[1];
        } else {
          // Fallback (keeps your existing behavior)
          pana = parts[0];
          digit = parts[1];
        }
      } else if (_isPanaGame()) {
        // ✅ Single/Double/Triple Pana -> server wants "pana" filled, "digit" empty
        // extra safety: accept only 3-digit numeric keys to avoid bad rows
        if (key.length == 3 && int.tryParse(key) != null) {
          pana = key;
          digit = '';
        } else {
          log('Skipping invalid pana key: $key', name: 'BidAPI');
          return;
        }
      } else {
        // Generic: single digit / jodi etc. -> send in "digit"
        digit = key;
        pana = '';
      }

      bidPayloadList.add({
        "sessionType": mode,
        "digit": digit,
        "pana": pana,
        "bidAmount": bidAmount,
      });
    });

    if (bidPayloadList.isEmpty) {
      return {'status': false, 'msg': 'No valid bids to submit.'};
    }

    final body = {
      "registerId": registerId,
      "gameId": gameId.toString(),
      "bidAmount": totalBidAmount,
      "gameType": gameType,
      "bid": bidPayloadList,
    };

    // Debug logs
    String curl = 'curl -X POST "$apiUrl"';
    headers.forEach((k, v) => curl += ' \\\n  -H "$k: $v"');
    curl += " \\\n  -d '${jsonEncode(body)}'";
    log('CURL Final Bid:\n$curl', name: 'BidAPI');
    log('Headers: $headers', name: 'BidAPI');
    log('Body   : ${jsonEncode(body)}', name: 'BidAPI');

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );
      log('HTTP ${res.statusCode}', name: 'BidAPI');
      log('Resp: ${res.body}', name: 'BidAPI');

      Map<String, dynamic> respJson;
      try {
        respJson = json.decode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'status': false, 'msg': 'Invalid server response.'};
      }

      if (res.statusCode == 200 && respJson['status'] == true) {
        return {'status': true, 'data': respJson};
      } else {
        return {
          'status': false,
          'msg': respJson['msg'] ?? 'Unknown error occurred.',
        };
      }
    } catch (e) {
      log('Network error during bid submission: $e', name: 'BidAPIError');
      return {
        'status': false,
        'msg': 'Network error. Please check your internet connection.',
      };
    }
  }

  Future<void> updateWalletBalance(int newBalance) async {
    await _storage.write('walletBalance', newBalance.toString());
  }

  Map<String, String> getBidAmounts(List<Map<String, String>> bids) {
    final Map<String, String> out = {};
    for (final b in bids) {
      out[b['digit']!] = b['amount']!;
    }
    return out;
  }
}

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:new_sara/ulits/Constents.dart';
//
// class BidService {
//   final GetStorage _storage;
//   BidService(this._storage);
//
//   Future<Map<String, dynamic>> placeFinalBids({
//     required String gameName,
//     required String accessToken,
//     required String registerId,
//     required String deviceId,
//     required String deviceName,
//     required bool accountStatus,
//     required Map<String, String> bidAmounts, // key -> points
//     required String
//     selectedGameType, // e.g. OPEN / CLOSE / FULLSANGAM / HALF BRACKET / FULL BRACKET
//     required int gameId,
//     required String gameType, // e.g. singlePana, fullSangam, etc.
//     required int totalBidAmount,
//   }) async {
//     final String apiUrl = Constant.apiEndpoint.endsWith('/')
//         ? '${Constant.apiEndpoint}place-bid'
//         : '${Constant.apiEndpoint}/place-bid';
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       return {
//         'status': false,
//         'msg': 'Authentication error. Please log in again.',
//       };
//     }
//
//     final headers = {
//       'deviceId': deviceId,
//       'deviceName': deviceName,
//       'accessStatus': accountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final String mode = selectedGameType.toUpperCase().trim();
//     final String gt = gameType.toLowerCase().trim();
//
//     /// Build the bid payload correctly for each game shape.
//     final List<Map<String, dynamic>> bidPayloadList = [];
//
//     bidAmounts.forEach((key, amountStr) {
//       final int bidAmount = int.tryParse(amountStr) ?? 0;
//       if (bidAmount <= 0) return;
//
//       String pana = '';
//       String digit = '';
//
//       if (mode.contains('BRACKET')) {
//         // Red Bracket -> single value key (digit/jodi), server expects it in "digit"
//         digit = key;
//         pana = '';
//       } else if (gt.contains('sangam')) {
//         // Sangam types come as "A-B"
//         final parts = key.split('-').map((e) => e.trim()).toList();
//         if (parts.length != 2) {
//           log('Skipping malformed Sangam key: $key', name: 'BidAPI');
//           return;
//         }
//         if (mode.contains('FULL')) {
//           // FullSangam: openPanna-closePanna
//           pana = parts[0];
//           digit = parts[1];
//         } else if (mode.contains('OPEN')) {
//           // Half Sangam A: openDigit-closePanna
//           digit = parts[0];
//           pana = parts[1];
//         } else if (mode.contains('CLOSE')) {
//           // Half Sangam B: openPanna-closeDigit
//           pana = parts[0];
//           digit = parts[1];
//         } else {
//           // Fallback
//           pana = parts[0];
//           digit = parts[1];
//         }
//       } else if (gt.contains('pana')) {
//         // ✅ Single/Double/Triple Pana -> server wants "pana" filled, "digit" empty
//         pana = key;
//         digit = '';
//       } else {
//         // Generic: single digit / jodi etc. -> send in "digit"
//         digit = key;
//         pana = '';
//       }
//
//       bidPayloadList.add({
//         "sessionType": mode,
//         "digit": digit,
//         "pana": pana,
//         "bidAmount": bidAmount,
//       });
//     });
//
//     if (bidPayloadList.isEmpty) {
//       return {'status': false, 'msg': 'No valid bids to submit.'};
//     }
//
//     final body = {
//       "registerId": registerId,
//       "gameId": gameId.toString(),
//       "bidAmount": totalBidAmount,
//       "gameType": gameType,
//       "bid": bidPayloadList,
//     };
//
//     // Debug logs
//     String curl = 'curl -X POST "$apiUrl"';
//     headers.forEach((k, v) => curl += ' \\\n  -H "$k: $v"');
//     curl += " \\\n  -d '${jsonEncode(body)}'";
//     log('CURL Final Bid:\n$curl', name: 'BidAPI');
//     log('Headers: $headers', name: 'BidAPI');
//     log('Body   : ${jsonEncode(body)}', name: 'BidAPI');
//
//     try {
//       final res = await http.post(
//         Uri.parse(apiUrl),
//         headers: headers,
//         body: jsonEncode(body),
//       );
//       log('HTTP ${res.statusCode}', name: 'BidAPI');
//       log('Resp: ${res.body}', name: 'BidAPI');
//
//       Map<String, dynamic> respJson;
//       try {
//         respJson = json.decode(res.body) as Map<String, dynamic>;
//       } catch (_) {
//         return {'status': false, 'msg': 'Invalid server response.'};
//       }
//
//       if (res.statusCode == 200 && respJson['status'] == true) {
//         return {'status': true, 'data': respJson};
//       } else {
//         return {
//           'status': false,
//           'msg': respJson['msg'] ?? 'Unknown error occurred.',
//         };
//       }
//     } catch (e) {
//       log('Network error during bid submission: $e', name: 'BidAPIError');
//       return {
//         'status': false,
//         'msg': 'Network error. Please check your internet connection.',
//       };
//     }
//   }
//
//   Future<void> updateWalletBalance(int newBalance) async {
//     await _storage.write('walletBalance', newBalance.toString());
//   }
//
//   Map<String, String> getBidAmounts(List<Map<String, String>> bids) {
//     final Map<String, String> out = {};
//     for (final b in bids) {
//       out[b['digit']!] = b['amount']!;
//     }
//     return out;
//   }
// }

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:new_sara/Helper/UserController.dart';
// import 'package:new_sara/ulits/Constents.dart';
//
// class BidService {
//   final GetStorage _storage;
//   BidService(this._storage);
//
//   Future<Map<String, dynamic>> placeFinalBids({
//     required String gameName,
//     required String accessToken,
//     required String registerId,
//     required String deviceId,
//     required String deviceName,
//     required bool accountStatus,
//     required Map<String, String> bidAmounts, // key -> points
//     required String
//     selectedGameType, // e.g. FULLSANGAM / OPEN / CLOSE / HALF BRACKET / FULL BRACKET
//     required int gameId,
//     required String gameType,
//     required int totalBidAmount,
//   }) async {
//     final String apiUrl = Constant.apiEndpoint.endsWith('/')
//         ? '${Constant.apiEndpoint}place-bid'
//         : '${Constant.apiEndpoint}/place-bid';
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       return {
//         'status': false,
//         'msg': 'Authentication error. Please log in again.',
//       };
//     }
//
//     final headers = <String, String>{
//       'deviceId': deviceId,
//       'deviceName': deviceName,
//       'accessStatus': accountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final String mode = selectedGameType.toUpperCase().trim();
//     final List<Map<String, dynamic>> bidPayloadList = [];
//
//     bidAmounts.forEach((key, amountStr) {
//       final int bidAmount = int.tryParse(amountStr) ?? 0;
//       if (bidAmount <= 0) return;
//
//       String pana = '';
//       String digit = '';
//
//       // Case 1: Red Bracket (single value key)
//       if (mode.contains('BRACKET')) {
//         digit = key; // jodi/digit as single value
//         pana = '';
//       }
//       // Case 2: Keys with hyphen => Sangam (A-B)
//       else if (key.contains('-')) {
//         final parts = key.split('-').map((e) => e.trim()).toList();
//         if (parts.length != 2) {
//           log('Skipping malformed Sangam key: $key', name: 'BidAPI');
//           return;
//         }
//
//         if (mode.contains('FULL')) {
//           // Full Sangam: openPanna-closePanna
//           pana = parts[0];
//           digit = parts[1];
//         } else if (mode.contains('OPEN')) {
//           // Half Sangam A: openDigit-closePanna  (digit-pana)
//           digit = parts[0];
//           pana = parts[1];
//         } else if (mode.contains('CLOSE')) {
//           // Half Sangam B: openPanna-closeDigit  (pana-digit)
//           pana = parts[0];
//           digit = parts[1];
//         } else {
//           // Fallback mapping
//           pana = parts[0];
//           digit = parts[1];
//         }
//       }
//       // Case 3: Single-digit/starline-like games (Odd/Even/Single etc.)
//       else {
//         digit = key;
//         pana = '';
//       }
//
//       bidPayloadList.add({
//         "sessionType": mode, // server expects uppercase
//         "digit": digit,
//         "pana": pana,
//         "bidAmount": bidAmount,
//       });
//     });
//
//     if (bidPayloadList.isEmpty) {
//       return {'status': false, 'msg': 'No valid bids to submit.'};
//     }
//
//     final body = {
//       "registerId": registerId,
//       "gameId": gameId.toString(),
//       "bidAmount": totalBidAmount,
//       "gameType": gameType,
//       "bid": bidPayloadList,
//     };
//
//     // Debug: cURL + payload logs
//     String curl = 'curl -X POST "$apiUrl"';
//     headers.forEach((k, v) => curl += ' \\\n  -H "$k: $v"');
//     curl += " \\\n  -d '${jsonEncode(body)}'";
//     log('CURL Final Bid:\n$curl', name: 'BidAPI');
//     log('Headers: $headers', name: 'BidAPI');
//     log('Body   : ${jsonEncode(body)}', name: 'BidAPI');
//
//     try {
//       final res = await http.post(
//         Uri.parse(apiUrl),
//         headers: headers,
//         body: jsonEncode(body),
//       );
//       log('HTTP ${res.statusCode}', name: 'BidAPI');
//       log('Resp: ${res.body}', name: 'BidAPI');
//
//       late final Map<String, dynamic> respJson;
//       try {
//         respJson = json.decode(res.body) as Map<String, dynamic>;
//       } catch (_) {
//         return {'status': false, 'msg': 'Invalid server response.'};
//       }
//
//       if (res.statusCode == 200 && (respJson['status'] == true)) {
//         return {'status': true, 'data': respJson};
//       } else {
//         return {
//           'status': false,
//           'msg': respJson['msg']?.toString() ?? 'Unknown error occurred.',
//         };
//       }
//     } catch (e) {
//       log('Network error during bid submission: $e', name: 'BidAPIError');
//       return {
//         'status': false,
//         'msg': 'Network error. Please check your internet connection.',
//       };
//     }
//   }
//
//   Future<void> updateWalletBalance(int newBalance) async {
//     // Persist in storage
//     await _storage.write('walletBalance', newBalance.toString());
//
//     // Also push to GetX so UI refreshes without relying on storage listeners
//     if (Get.isRegistered<UserController>()) {
//       final uc = Get.find<UserController>();
//       uc.walletBalance.value = newBalance.toString();
//     }
//   }
//
//   Map<String, String> getBidAmounts(List<Map<String, String>> bids) {
//     final Map<String, String> out = {};
//     for (final b in bids) {
//       final k = b['digit'];
//       final v = b['amount'];
//       if (k != null && v != null) out[k] = v;
//     }
//     return out;
//   }
// }
