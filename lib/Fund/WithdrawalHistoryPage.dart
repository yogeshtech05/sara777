import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart';
import 'package:new_sara/components/showWalletFundHistoryDialog.dart';
import 'package:new_sara/components/PaginationBar.dart';

class WithdrawalHistoryPage extends StatefulWidget {
  final VoidCallback? onBack;
  const WithdrawalHistoryPage({super.key, this.onBack});

  @override
  State<WithdrawalHistoryPage> createState() => _WithdrawalHistoryPageState();
}

class _WithdrawalHistoryPageState extends State<WithdrawalHistoryPage> {
  late Future<List<WithdrawalItem>> _withdrawFuture;
  final String apiUrl = '${Constant.apiEndpoint}withdrawal-fund-history';
  final GetStorage storage = GetStorage();
  String accessToken = '';
  String registerId = '';
  int pageIndex = 1;
  int _totalPages = 1;


  @override
  void initState() {
    super.initState();
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';

    _withdrawFuture = fetchWithdrawals(); // Initial fetch

    storage.listenKey('accessToken', (value) {
      if (mounted) {
        setState(() {
          accessToken = value ?? '';
          _withdrawFuture = fetchWithdrawals(); // Re-fetch on token change
        });
      }
    });

    storage.listenKey('registerId', (value) {
      if (mounted) {
        setState(() {
          registerId = value ?? '';
          _withdrawFuture = fetchWithdrawals(); // Re-fetch on ID change
        });
      }
    });
  }

  Future<List<WithdrawalItem>> fetchWithdrawals() async {
    if (accessToken.isEmpty || registerId.isEmpty) {
      print('Access Token or Register ID is empty. Skipping API call.');
      return [];
    }

    final url = Uri.parse(apiUrl);
    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      'registerId': registerId,
      'pageIndex': pageIndex,
      'recordLimit': 10,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // CASE 1: No record found
        if (responseData['status'] == false ||
            responseData['info'] == "" ||
            responseData['info'] == null) {
          print("No record found. Returning empty list.");
          if (mounted) {
            setState(() {
              _totalPages = 0;
            });
          }
          return [];
        }

        // CASE 2: When info contains list
        if (responseData['info'] is Map) {
          final info = responseData['info'] as Map<String, dynamic>;
          final totalPagesVal = info['totalPages'] as int? ?? 1;
          if (mounted) {
            setState(() {
              _totalPages = totalPagesVal;
            });
          }
          if (info['list'] is List) {
            return (info['list'] as List)
                .map((e) => WithdrawalItem.fromJson(e))
                .toList();
          }
        }

        print("Unexpected response structure: $responseData");
        return [];
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("ERROR: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          'Fund Withdraw History',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey.shade300,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<WithdrawalItem>>(
                future: _withdrawFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: ${snapshot.error.toString()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    );
                  }

                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    Future.delayed(Duration.zero, () {
                      showWalletFundHistoryDialog(context, message: "Withdraw Trasaction Data Not Available");
                    });
                    return const Center(child: Text("No withdraw history found."));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// Date & Status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.requestDate,
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        item.statusText.toLowerCase() == 'completed'
                                            ? Icons.check_circle
                                            : item.statusText.toLowerCase() ==
                                                  'pending'
                                            ? Icons.access_time
                                            : Icons.cancel,
                                        size: 16,
                                        color:
                                            item.statusText.toLowerCase() ==
                                                'completed'
                                            ? Colors.green
                                            : item.statusText.toLowerCase() ==
                                                  'pending'
                                            ? Colors.orange
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.statusText,
                                        style: TextStyle(
                                          color:
                                              item.statusText.toLowerCase() ==
                                                  'completed'
                                              ? Colors.green
                                              : item.statusText.toLowerCase() ==
                                                    'pending'
                                              ? Colors.orange
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(),

                              /// Amount
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Amount",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  Text(
                                    "₹ ${item.amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              /// Narration
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Withdraw Mode",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  Flexible(
                                    child: Text(
                                      item.withdrawMode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.upiId.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "UPI ID",
                                        style: TextStyle(color: Colors.black),
                                      ),
                                      Flexible(
                                        child: Text(
                                          item.upiId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (item.bankName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "Bank Name",
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                          Flexible(
                                            child: Text(
                                              item.bankName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "A/C Holder",
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                          Flexible(
                                            child: Text(
                                              item.accountHolderName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "A/C No.",
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                          Flexible(
                                            child: Text(
                                              item.accountNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "IFSC Code",
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                          Flexible(
                                            child: Text(
                                              item.ifscCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
                        _withdrawFuture = fetchWithdrawals();
                      });
                    }
                  : null,
              onNext: pageIndex < _totalPages
                  ? () {
                      setState(() {
                        pageIndex++;
                        _withdrawFuture = fetchWithdrawals();
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

class WithdrawalItem {
  final String requestDate;
  final double amount;
  final String fundId;
  final String withdrawMode;
  final String upiId;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String requestType;
  final String statusText;

  WithdrawalItem({
    required this.requestDate,
    required this.amount,
    required this.fundId,
    required this.withdrawMode,
    required this.upiId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.requestType,
    required this.statusText,
  });

  factory WithdrawalItem.fromJson(Map<String, dynamic> json) {
    return WithdrawalItem(
      requestDate: json['requestDate'] as String? ?? 'N/A',
      amount: double.tryParse(json['amount'] as String? ?? '0.0') ?? 0.0,
      fundId: json['fundId'] as String? ?? '',
      withdrawMode: json['withdrawMode'] as String? ?? 'N/A',
      upiId: json['upiId'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      accountHolderName: json['accountHolderName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      ifscCode: json['ifscCode'] as String? ?? '',
      requestType: json['requestType'] as String? ?? 'N/A',
      statusText: json['statusText'] as String? ?? 'Unknown',
    );
  }
}
