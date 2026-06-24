import 'package:flutter/material.dart';
import 'package:new_sara/Bids/BidHistory/BidHistoryScreen.dart';
import 'package:new_sara/Bids/KingJackpotBidHis/KingJackpotHistoryScreen.dart';
import 'package:new_sara/Bids/KingStartlineBidHis/KingStarlineBidHistoryScreen.dart';
import 'package:new_sara/game/GameResults/GameResultScreen.dart';
import 'package:new_sara/Bids/KingStarlineResultHis/KingStarlineResultHis.dart';
import 'package:new_sara/Bids/KingJackpotResultHis/KingJackpotResultScreen.dart';

class BidScreen extends StatelessWidget {
  final List<_BidOption> bidOptions = [
    _BidOption(
      "BID HISTORY",
      "You can view your market bid history",
      "assets/images/bid_history_wallet.png",
    ),
    _BidOption(
      "Game Results",
      "You can view your market result history",
      "assets/images/game_results.png",
    ),
    _BidOption(
      "King Starline Bid History",
      "You can view your starline bid history",
      "assets/images/bank_emoji.png",
    ),
    _BidOption(
      "King Starline Result History",
      "You can view your starline result",
      "assets/images/bid_history_wallet.png",
    ),
    _BidOption(
      "KING JACKPOT BID HISTORY",
      "You can view your jackpot bid history",
      "assets/images/game_results.png",
    ),
    _BidOption(
      "KING JACKPOT RESULT HISTORY",
      "You can view your jackpot result",
      "assets/images/bank_emoji.png",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: bidOptions.length,
        itemBuilder: (context, index) {
          final item = bidOptions[index];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (item.title == "BID HISTORY") {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => BidHistoryPage()),
                  );
                }
                if (item.title == "Game Results") {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => GameResultScreen()),
                  );
                }
                if (item.title == "King Starline Bid History") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingStarlineBidHistoryScreen(),
                    ),
                  );
                }
                if (item.title == "King Starline Result History") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingStarlineResultScreen(),
                    ),
                  );
                }
                if (item.title == "KING JACKPOT BID HISTORY") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingJackpotHistoryScreen(),
                    ),
                  );
                }
                if (item.title == "KING JACKPOT RESULT HISTORY") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingJackpotResultScreen(),
                    ),
                  );
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
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 14.5,
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
    );
  }
}

class _BidOption {
  final String title;
  final String subtitle;
  final String assetIconPath;

  _BidOption(this.title, this.subtitle, this.assetIconPath);
}
