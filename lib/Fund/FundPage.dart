import 'package:flutter/material.dart';
import 'package:new_sara/Fund/BankDetailsFragment.dart';

import '../Helper/TranslationHelper.dart';
import 'AddFundScreen.dart';
import 'DepositHistoryPage.dart';
import 'WithdrawScreen.dart';
import 'WithdrawalHistoryPage.dart';

class FundsScreen extends StatelessWidget {
  final void Function(String title)? onItemTap;
  TranslationHelper translationHelper = TranslationHelper();

  FundsScreen({super.key, this.onItemTap});

  final List<_FundOption> fundOptions = [
    _FundOption(
      "Add Fund",
      "You can add fund to your wallet",
      "assets/images/add_fund.png",
    ),
    _FundOption(
      "Withdraw Fund",
      "You can withdraw winnings",
      "assets/images/withdrawl_fund.png",
    ),
    _FundOption(
      "Add Bank Details",
      "You can add your bank details for withdrawls",
      "assets/images/add_bank_details.png",
    ),
    _FundOption(
      "Fund Deposit History",
      "You can see history of your deposit",
      "assets/images/fund_deposite_history.png",
    ),
    _FundOption(
      "Fund Withdraw History",
      "You can see history of your fund withdrawls",
      "assets/images/fund_withdraw_history.png",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFFEEEEEE),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: fundOptions.length,
          itemBuilder: (context, index) {
            final item = fundOptions[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08), // Increased for elevation
                    blurRadius: 10,
                    offset: const Offset(0, 4), // Increased for elevation
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (onItemTap != null) {
                    onItemTap!(item.title);
                  } else {
                    switch (item.title) {
                      case "Add Fund":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddFundScreen(),
                          ),
                        );
                        break;
                      case "Withdraw Fund":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WithdrawScreen(),
                          ),
                        );
                        break;
                      case "Add Bank Details":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BankDetailsFragment(),
                          ),
                        );
                        break;
                      case "Fund Deposit History":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DepositHistoryPage(),
                          ),
                        );
                        break;
                      case "Fund Withdraw History":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WithdrawalHistoryPage(),
                          ),
                        );
                        break;
                      default:
                        break;
                    }
                  }
                },
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Image.asset(
                    item.assetIconPath,
                    width: 36,
                    height: 36,
                    color: const Color(0xFFF9B233),
                    errorBuilder: (_, __, ___) => const Icon(Icons.error),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900, // Increased
                      color: Colors.black87,
                      fontSize: 14.5, // Reverted size
                    ),
                  ),
                  subtitle: Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                  trailing: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_right,
                      color: Color(0xFFF9B233),
                      size: 20,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FundOption {
  final String title;
  final String subtitle;
  final String assetIconPath;

  _FundOption(this.title, this.subtitle, this.assetIconPath);
}
