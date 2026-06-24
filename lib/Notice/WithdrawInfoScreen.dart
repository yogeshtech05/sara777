import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WithdrawInfoScreen extends StatelessWidget {
  const WithdrawInfoScreen({super.key});

  void _launchWhatsApp() async {
    const url = "https://wa.me/919649115777";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    const thumbsUp = "👍";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Information", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Withdraw Information",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            /// Withdraw Rules
            const Text(
              "$thumbsUp If UserEntered Wrong Bank Details Sara777 Is Not Responsible",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "$thumbsUp Before Requesting Withdraw Re-check Your Bank Details.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "$thumbsUp After Withdraw Request If There Is No Valid Wallet Balance The Request Will Be Auto Declined.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Divider(),

            /// WhatsApp Contact
            GestureDetector(
              onTap: _launchWhatsApp,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Image(
                    image: AssetImage("assets/images/ic_whatsapp.png"),
                    width: 28,
                    height: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "919649115777",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),

            /// Unfair Bets Section
            const Text(
              "Unfair Bets",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "If Admin Found Any Unfair-bets, Blocking Of Digits, Canning Or Match Fix Bets.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "Admin Has All Right To Take Necessary Action To Block The User.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Divider(),

            /// Cheating Bets Section
            const Text(
              "Cheating Bets",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "If Admin Found Any Cheating, Hacking, Phishing Admin Has All Right To Take Necessary Action To Block The User.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
