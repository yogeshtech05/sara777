import 'package:flutter/material.dart';
import 'package:new_sara/Fund/BankDetailsFragment.dart';

import '../Fund/AddFundScreen.dart';
import '../Fund/FundPage.dart';
import '../Fund/WithdrawScreen.dart';
import '../Fund/DepositHistoryPage.dart';
import '../Fund/WithdrawalHistoryPage.dart';

// this file is for navigation of funds and related pages within the Add Fund Screen
class FundsFragmentContainer extends StatefulWidget {
  const FundsFragmentContainer({super.key});

  @override
  State<FundsFragmentContainer> createState() => _FundsFragmentContainerState();
}

class _FundsFragmentContainerState extends State<FundsFragmentContainer> {
  late Widget _currentScreen;

  @override
  void initState() {
    super.initState();
    _currentScreen = FundsScreen(onItemTap: _handleItemTap);
  }

  void _handleItemTap(String title) {
    setState(() {
      switch (title) {
        case "Add Fund":
          _currentScreen = _wrapBack(AddFundScreen(
            onBack: () {
              setState(() {
                _currentScreen = FundsScreen(onItemTap: _handleItemTap);
              });
            },
          ));
          break;
        case "Withdraw Fund":
          _currentScreen = _wrapBack(WithdrawScreen());
          break;
        case "Add Bank Details":
          _currentScreen = _wrapBack(BankDetailsFragment());
          break;
        case "Fund Deposit History":
          _currentScreen = _wrapBack(DepositHistoryPage(
            onBack: () {
              setState(() {
                _currentScreen = FundsScreen(onItemTap: _handleItemTap);
              });
            },
          ));
          break;
        case "Fund Withdraw History":
          _currentScreen = _wrapBack(WithdrawalHistoryPage(
            onBack: () {
              setState(() {
                _currentScreen = FundsScreen(onItemTap: _handleItemTap);
              });
            },
          ));
          break;
        case "Bank Changes History":
          _currentScreen = _wrapBack(_DummyScreen("Bank Changes History"));
          break;
        default:
          _currentScreen = FundsScreen(onItemTap: _handleItemTap);
      }
    });
  }

  Widget _wrapBack(Widget child) {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _currentScreen = FundsScreen(onItemTap: _handleItemTap);
        });
        return false; // prevent system pop
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _currentScreen,
    );
  }
}

class _DummyScreen extends StatelessWidget {
  final String title;
  const _DummyScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
