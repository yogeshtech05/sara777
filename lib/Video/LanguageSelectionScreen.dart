import 'package:flutter/material.dart';

import 'VideoScreen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  void navigateToVideo(BuildContext context, String language) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoScreen(language: language)),
    );
  }

  Widget languageButton(BuildContext context, String title, String subtitle) {
    return GestureDetector(
      onTap: () => navigateToVideo(context, title),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F3),
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        title: const Text(
          "Choose Your Preferred Language",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: Colors.grey.shade300, // Change to any color you prefer
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    languageButton(context, "HINDI", "हिन्दी"),
                    languageButton(context, "ENGLISH", "English"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
