import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BidConfirmationDialog extends StatelessWidget {
  final String gameTitle;
  final String gameDate;
  final List<Map<String, String>> bids;
  final int totalBids;
  final int totalBidsAmount;
  final int walletBalanceBeforeDeduction;
  final String? walletBalanceAfterDeduction;
  final String gameId;
  final String gameType;
  final VoidCallback onConfirm;

  const BidConfirmationDialog({
    Key? key,
    required this.gameTitle,
    required this.gameDate,
    required this.bids,
    required this.totalBids,
    required this.totalBidsAmount,
    required this.walletBalanceBeforeDeduction,
    this.walletBalanceAfterDeduction,
    required this.gameId,
    required this.gameType,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int finalWalletBalanceAfterDeduction =
        int.tryParse(walletBalanceAfterDeduction ?? '') ??
        (walletBalanceBeforeDeduction - totalBidsAmount);

    final String formattedDateTime = DateFormat('hh:mm a - dd-MMM-yyyy').format(DateTime.now());

    String firstHeader = 'Digit';
    final gt = gameType.toLowerCase();
    if (gt.contains('jodi')) {
      firstHeader = 'Jodi';
    } else if (gt.contains('pana') || gt.contains('panna')) {
      firstHeader = 'Pana';
    }

    final bool showType = bids.any((b) => b['type'] != null && b['type']!.isNotEmpty);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.78,
              maxHeight: MediaQuery.of(context).size.height * 0.78,
              minWidth: 320,
              maxWidth: 600,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full-width Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9B233),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Text(
                      formattedDateTime,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                  
                  // Content padding wrapper
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBidListHeader(showType, firstHeader),
                          const SizedBox(height: 6),
                          Expanded(
                            child: _buildBidList(context, showType),
                          ),
                          const SizedBox(height: 16),
                          
                          // 2-column Summary layout
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSummaryItem('Total Bids', totalBids.toString()),
                                    const SizedBox(height: 12),
                                    _buildSummaryItem(
                                      'Wallet Balance\nBefore Deduction',
                                      walletBalanceBeforeDeduction.toString(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSummaryItem('Total Bid Amount', totalBidsAmount.toString()),
                                    const SizedBox(height: 12),
                                    _buildSummaryItem(
                                      'Wallet Balance\nAfter Deduction',
                                      finalWalletBalanceAfterDeduction.toString(),
                                      isNegative: finalWalletBalanceAfterDeduction < 0,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Centered red text note
                          Text(
                            '* Note: Bid Once Played Can Not Be Cancelled *',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFFD32F2F), // Red note color
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Bottom buttons row: SUBMIT (left, orange) & CANCEL (right, orange)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onConfirm();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF9B233),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      'SUBMIT',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF9B233),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      'CANCEL',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBidListHeader(bool showType, String firstHeader) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: showType ? 2 : 1,
            child: Text(
              firstHeader,
              textAlign: showType ? TextAlign.start : TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 13.5, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: showType ? 2 : 1,
            child: Text(
              'Points',
              style: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 13.5, color: Colors.black87),
              textAlign: showType ? TextAlign.start : TextAlign.center,
            ),
          ),
          if (showType)
            Expanded(
              flex: 1,
              child: Text(
                'Type',
                style: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 13.5, color: Colors.black87),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBidList(BuildContext context, bool showType) {
    return ListView.builder(
      itemCount: bids.length,
      itemBuilder: (context, index) {
        final bid = bids[index];
        final displayPoints = bid['points'] ?? bid['amount'] ?? '';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: showType ? 2 : 1,
                child: Text(
                  bid['digit'] ?? '',
                  textAlign: showType ? TextAlign.start : TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                ),
              ),
              Expanded(
                flex: showType ? 2 : 1,
                child: Text(
                  displayPoints,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                  textAlign: showType ? TextAlign.start : TextAlign.center,
                ),
              ),
              if (showType)
                Expanded(
                  flex: 1,
                  child: Text(
                    bid['type'] ?? '',
                    style: GoogleFonts.poppins(color: Colors.green[700], fontSize: 14, fontWeight: FontWeight.normal),
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: isNegative ? const Color(0xFFD32F2F) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
