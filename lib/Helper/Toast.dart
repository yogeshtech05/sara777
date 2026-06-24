import 'dart:ui';

import 'package:fluttertoast/fluttertoast.dart';

void popToast(
    String message, int time, Color textColor, Color backgorund) async {
  await Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: time,
      backgroundColor: backgorund,
      textColor: textColor,
      fontSize: 14);
}