// lib/services/bid_service.dart
import 'dart:convert';
import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart'; // Make sure this path is correct

class BidServiceBulk {
  final GetStorage _storage;

  BidServiceBulk(this._storage);

  Future<Map<String, dynamic>> placeFinalBids({
    required String gameName, // Used to determine endpoint
    required String accessToken,
    required String registerId,
    required String deviceId,
    required String deviceName,
    required bool accountStatus,
    required List<Map<String, String>>
    bids, // Changed to List<Map<String, String>>
    required String
    gameType, // This is the widget.gameType (e.g., "jodi", "single")
    required int gameId,
    required int totalBidAmount,
    required String selectedSessionType, // For 'sessionType' in bid payload
  }) async {
    String apiUrl;
    if (gameName.toLowerCase().contains('jackpot')) {
      apiUrl = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (gameName.toLowerCase().contains('starline')) {
      apiUrl = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      apiUrl = '${Constant.apiEndpoint}place-bid';
    }

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

    final List<Map<String, dynamic>> bidPayloadList = [];
    for (var bid in bids) {
      bidPayloadList.add({
        "sessionType": selectedSessionType, // Use the passed session type
        "digit": bid['jodi'], // Assuming 'jodi' is the digit for the bid
        "pana": "", // Digit board might not have pana in this context
        "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
      });
    }

    final body = {
      "registerId": registerId,
      "gameId": gameId.toString(),
      "bidAmount": totalBidAmount,
      "gameType": gameType, // The overall game type for the request
      "bid": bidPayloadList,
    };

    // --- Logging cURL command for debugging ---
    String curlCommand = 'curl -X POST \\\n  $apiUrl \\';
    headers.forEach((key, value) {
      curlCommand += '\n  -H "$key: $value" \\';
    });
    curlCommand += '\n  -d \'${jsonEncode(body)}\'';

    log('CURL Command for Final Bid Submission:\n$curlCommand', name: 'BidAPI');
    log('Request Headers for Final Bid Submission: $headers', name: 'BidAPI');
    log(
      'Request Body for Final Bid Submission: ${jsonEncode(body)}',
      name: 'BidAPI',
    );
    // --- End logging ---

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      log('Response Status Code: ${response.statusCode}', name: 'BidAPI');
      log('Response Body: ${response.body}', name: 'BidAPI');

      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        return {'status': true, 'data': responseBody};
      } else {
        return {
          'status': false,
          'msg': responseBody['msg'] ?? "Unknown error occurred.",
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
}
