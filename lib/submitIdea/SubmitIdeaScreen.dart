import 'package:flutter/material.dart';

class SubmitIdeaScreen extends StatefulWidget {
  @override
  _SubmitIdeaScreenState createState() => _SubmitIdeaScreenState();
}

class _SubmitIdeaScreenState extends State<SubmitIdeaScreen> {
  final TextEditingController _controller = TextEditingController();
  final int _maxLength = 500;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEFEFEF),
      appBar: AppBar(
        backgroundColor: Color(0xFFEFEFEF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Your Idea",
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 200,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                maxLength: _maxLength,
                decoration: InputDecoration.collapsed(
                  hintText: "Write your idea here...",
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${_controller.text.length}/$_maxLength",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 3,
              ),
              onPressed: () {
                // Add submission logic here
                print("Idea Submitted: ${_controller.text}");
              },
              child: Text(
                "SUBMIT YOUR IDEA",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
