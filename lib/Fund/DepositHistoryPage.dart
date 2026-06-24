import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/components/showWalletFundHistoryDialog.dart';
import 'package:new_sara/components/PaginationBar.dart';
import '../ulits/Constents.dart';

class DepositHistoryPage extends StatefulWidget {
  final VoidCallback? onBack;
  const DepositHistoryPage({Key? key, this.onBack}) : super(key: key);

  @override
  State<DepositHistoryPage> createState() => _DepositHistoryPageState();
}

class _DepositHistoryPageState extends State<DepositHistoryPage> {
  late Future<List<DepositHistoryItem>> _depositFuture;
  final storage = GetStorage();

  String accessToken = '';
  String registerId = '';
  int pageIndex = 1;
  int _totalPages = 1;


  @override
  void initState() {
    super.initState();

    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';

    log("Access Token: $accessToken");
    log("Register Id: $registerId");

    _depositFuture = fetchDepositHistory();
  }

  Future<List<DepositHistoryItem>> fetchDepositHistory() async {
    final uri = Uri.parse('${Constant.apiEndpoint}deposit-fund-history');

    final requestBody = jsonEncode({
      'registerId': registerId,
      'pageIndex': pageIndex,
      'recordLimit': 10,
    });

    log("Deposit History Request Body: $requestBody");

    try {
      final response = await http.post(
        uri,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: requestBody,
      );

      final data = jsonDecode(response.body);
      debugPrint('API Response: $data');
      log('API Response Status Code: ${response.statusCode}');
      log('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        if (data['status'] == true && data['info'] != null) {
          final info = data['info'] as Map<String, dynamic>;
          final List<dynamic> list = info['list'] ?? [];
          final totalPagesVal = info['totalPages'] as int? ?? 1;

          if (mounted) {
            setState(() {
              _totalPages = totalPagesVal;
            });
          }
          return list.map((item) => DepositHistoryItem.fromJson(item)).toList();
        } else {
          debugPrint('API status is false or info is null: ${data['msg']}');
          if (mounted) {
            setState(() {
              _totalPages = 0;
            });
          }
          return [];
        }
      } else {
        throw Exception(
          'Failed to load deposit history: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception fetching deposit history: $e');
      throw Exception('Failed to load deposit history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text(
          'Fund Deposit History',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey.shade300,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<DepositHistoryItem>>(
                future: _depositFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    Future.delayed(Duration.zero, () {
                      showWalletFundHistoryDialog(context, message: "Wallet Fund History Not Available");
                    });
                    return const Center(child: Text('No deposit history found'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      Color statusColor = Colors.grey;
                      IconData statusIcon = Icons.info_outline;
                      if (item.statusText.toLowerCase() == 'completed') {
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle;
                      } else if (item.statusText.toLowerCase() == 'pending') {
                        statusColor = Colors.orange;
                        statusIcon = Icons.access_time;
                      } else if (item.statusText.toLowerCase() == 'failed' ||
                          item.statusText.toLowerCase() == 'rejected') {
                        statusColor = Colors.orange;
                        statusIcon = Icons.cancel;
                      }

                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.requestDate,
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                  Row(
                                    children: [
                                      Icon(statusIcon, size: 16, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.statusText,
                                        style: TextStyle(color: statusColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Amount",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  Text(
                                    "₹ ${item.amount}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Narration",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  Text(
                                    item.remark,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            PaginationBar(
              pageIndex: pageIndex,
              totalPages: _totalPages,
              onPrevious: pageIndex > 1
                  ? () {
                      setState(() {
                        pageIndex--;
                        _depositFuture = fetchDepositHistory();
                      });
                    }
                  : null,
              onNext: pageIndex < _totalPages
                  ? () {
                      setState(() {
                        pageIndex++;
                        _depositFuture = fetchDepositHistory();
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class DepositHistoryItem {
  final String txId;
  final String requestDate;
  final String amount;
  final String remark;
  final String statusText;

  DepositHistoryItem({
    required this.txId,
    required this.requestDate,
    required this.amount,
    required this.remark,
    required this.statusText,
  });

  factory DepositHistoryItem.fromJson(Map<String, dynamic> json) {
    return DepositHistoryItem(
      txId: json['txId'] ?? '',
      requestDate: json['requestDate'] ?? 'Unknown Date',
      amount: json['amount']?.toString() ?? '0',
      remark: json['remark'] ?? 'No Details',
      statusText: json['statusText'] ?? 'Unknown Status',
    );
  }
}
