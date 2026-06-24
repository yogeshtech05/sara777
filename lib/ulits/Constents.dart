import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ColorsR.dart';

final GlobalKey<ScaffoldState> globalKey = GlobalKey<ScaffoldState>();
showErrorDialog(String mgs, String type) {
  Get.snackbar(
    type,
    mgs,
    colorText: Colors.white,
    backgroundColor: ColorsR.appColor,
    snackPosition: SnackPosition.BOTTOM,
  );
}



class Constant {
  static String somethingWentWrong = "something_went_wrong";
  //static String apiEndpoint = "https://admin.sara777.app/api/v1/";
  static String apiEndpoint = "https://admin.saraa777apk.com/api/v1/";
}
