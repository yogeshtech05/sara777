import 'dart:convert';
import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart';

enum Market { starline, jackpot }

class StarlineBidService {
  final GetStorage _storage;
  StarlineBidService(this._storage);

  Future<Map<String, dynamic>> placeFinalBids({
    required Market market,
    required String accessToken,
    required String registerId,
    required String deviceId,
    required String deviceName,
    required bool accountStatus,
    required Map<String, String> bidAmounts, // digit -> amount (string)
    required String gameType, // e.g. "jodi", "singleDigits"
    required int gameId, // TYPE id (int) — sent as STRING
    required int totalBidAmount,
  }) async {
    // Basic validation
    if (accessToken.isEmpty || registerId.isEmpty) {
      return {
        'status': false,
        'msg': 'Authentication error. Please log in again.',
      };
    }
    if (gameId <= 0) {
      return {'status': false, 'msg': 'Invalid gameId/type id.'};
    }

    // Build bids (sessionType is "" for BOTH markets as per your API)
    final bids = bidAmounts.entries
        .map((e) {
          final amt = int.tryParse(e.value) ?? 0;
          return <String, dynamic>{
            'sessionType': '',
            'digit': e.key,
            'pana': e.key,
            'bidAmount': amt,
          };
        })
        .where((b) => (b['bidAmount'] as int) > 0)
        .toList();

    if (bids.isEmpty)
      return {'status': false, 'msg': 'No valid bids to submit.'};

    final recomputedTotal = bids.fold<int>(
      0,
      (s, b) => s + (b['bidAmount'] as int),
    );

    // Only endpoint changes
    final apiUrl = market == Market.starline
        ?'${Constant.apiEndpoint}place-starline-bid'
        :'${Constant.apiEndpoint}place-jackpot-bid';

    // Headers exactly like Postman
    final headers = <String, String>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final body = <String, dynamic>{
      'registerId': registerId,
      'gameId': gameId.toString(), // STRING
      'bidAmount': totalBidAmount,
      'gameType': gameType, // e.g. "jodi"
      'bid': bids, // sessionType: ""
    };

    log('[BidAPI] URL: $apiUrl', name: 'BidAPI');
    log('[BidAPI] Headers: $headers', name: 'BidAPI');
    log(
      '[BidAPI] RecomputedTotal=$recomputedTotal, ProvidedTotal=$totalBidAmount',
      name: 'BidAPI',
    );
    log('[BidAPI] Body: ${jsonEncode(body)}', name: 'BidAPI');

    try {
      final resp = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );
      log('[BidAPI] Status: ${resp.statusCode}', name: 'BidAPI');
      log('[BidAPI] Resp: ${resp.body}', name: 'BidAPI');

      Map<String, dynamic> jsonResp;
      try {
        jsonResp = json.decode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        return {'status': false, 'msg': 'Invalid server response.'};
      }

      final ok = resp.statusCode == 200 && (jsonResp['status'] == true);
      if (ok) {
        // {status, msg, info}
        return {
          'status': true,
          'msg': (jsonResp['msg'] ?? 'Bid placed successfully.').toString(),
          'info': jsonResp['info'],
          'data': jsonResp,
        };
      } else {
        return {
          'status': false,
          'msg': (jsonResp['msg'] ?? 'Unknown error occurred.').toString(),
          'data': jsonResp,
          'code': resp.statusCode,
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

  /// Helper: convert [{digit, amount}] -> {digit: amount}
  Map<String, String> getBidAmounts(List<Map<String, String>> bids) {
    final out = <String, String>{};
    for (final b in bids) {
      final d = b['digit'];
      final a = b['amount'];
      if (d != null && a != null) out[d] = a;
    }
    return out;
  }
}
