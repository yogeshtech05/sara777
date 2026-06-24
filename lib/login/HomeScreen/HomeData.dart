// To parse this JSON data, do
//
//     final homeData = homeDataFromJson(jsonString);

import 'dart:convert';

HomeData homeDataFromJson(String str) => HomeData.fromJson(json.decode(str));

String homeDataToJson(HomeData data) => json.encode(data.toJson());

class HomeData {
  String? appLink;
  String? shareMsg;
  String? shareReferralContent;
  String? displayReferralContent;
  int? withdrawStatus;
  String? appMaintainenceMsg;
  String? maintainenceMsgStatus;
  String? appMarqueeMsg;
  String? userCurrentVersion;
  String? userMinimumVersion;
  String? popStatus;
  String? message;
  String? link;
  String? linkBtnText;
  String? actionType;
  String? actionBtnText;
  String? appDate;
  String? walletAmt;
  String? userName;
  String? mobile;
  String? transferPointStatus;
  String? bettingStatus;
  String? accountBlockStatus;
  String? referralCode;
  List<DeviceResult>? deviceResult;
  List<Result>? result;
  String? mobileNo;
  String? telegramNo;
  String? msg;
  bool? status;

  HomeData({
    this.appLink,
    this.shareMsg,
    this.shareReferralContent,
    this.displayReferralContent,
    this.withdrawStatus,
    this.appMaintainenceMsg,
    this.maintainenceMsgStatus,
    this.appMarqueeMsg,
    this.userCurrentVersion,
    this.userMinimumVersion,
    this.popStatus,
    this.message,
    this.link,
    this.linkBtnText,
    this.actionType,
    this.actionBtnText,
    this.appDate,
    this.walletAmt,
    this.userName,
    this.mobile,
    this.transferPointStatus,
    this.bettingStatus,
    this.accountBlockStatus,
    this.referralCode,
    this.deviceResult,
    this.result,
    this.mobileNo,
    this.telegramNo,
    this.msg,
    this.status,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    appLink: json["app_link"],
    shareMsg: json["share_msg"],
    shareReferralContent: json["share_referral_content"],
    displayReferralContent: json["display_referral_content"],
    withdrawStatus: json["withdraw_status"],
    appMaintainenceMsg: json["app_maintainence_msg"],
    maintainenceMsgStatus: json["maintainence_msg_status"],
    appMarqueeMsg: json["app_marquee_msg"],
    userCurrentVersion: json["user_current_version"],
    userMinimumVersion: json["user_minimum_version"],
    popStatus: json["pop_status"],
    message: json["message"],
    link: json["link"],
    linkBtnText: json["link_btn_text"],
    actionType: json["action_type"],
    actionBtnText: json["action_btn_text"],
    appDate: json["app_date"],
    walletAmt: json["wallet_amt"],
    userName: json["user_name"],
    mobile: json["mobile"],
    transferPointStatus: json["transfer_point_status"],
    bettingStatus: json["betting_status"],
    accountBlockStatus: json["account_block_status"],
    referralCode: json["referral_code"],
    deviceResult: List<DeviceResult>.from(json["device_result"].map((x) => DeviceResult.fromJson(x))),
    result: List<Result>.from(json["result"].map((x) => Result.fromJson(x))),
    mobileNo: json["mobile_no"],
    telegramNo: json["telegram_no"],
    msg: json["msg"],
    status: json["status"],
  );

  Map<String, dynamic> toJson() => {
    "app_link": appLink,
    "share_msg": shareMsg,
    "share_referral_content": shareReferralContent,
    "display_referral_content": displayReferralContent,
    "withdraw_status": withdrawStatus,
    "app_maintainence_msg": appMaintainenceMsg,
    "maintainence_msg_status": maintainenceMsgStatus,
    "app_marquee_msg": appMarqueeMsg,
    "user_current_version": userCurrentVersion,
    "user_minimum_version": userMinimumVersion,
    "pop_status": popStatus,
    "message": message,
    "link": link,
    "link_btn_text": linkBtnText,
    "action_type": actionType,
    "action_btn_text": actionBtnText,
    "app_date": appDate,
    "wallet_amt": walletAmt,
    "user_name": userName,
    "mobile": mobile,
    "transfer_point_status": transferPointStatus,
    "betting_status": bettingStatus,
    "account_block_status": accountBlockStatus,
    "referral_code": referralCode,
    "device_result": List<dynamic>.from(deviceResult!.map((x) => x.toJson())),
    "result": List<dynamic>.from(result!.map((x) => x.toJson())),
    "mobile_no": mobileNo,
    "telegram_no": telegramNo,
    "msg": msg,
    "status": status,
  };
}

class DeviceResult {
  String id;
  String userId;
  String deviceId;
  String logoutStatus;
  String securityPinStatus;

  DeviceResult({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.logoutStatus,
    required this.securityPinStatus,
  });

  factory DeviceResult.fromJson(Map<String, dynamic> json) => DeviceResult(
    id: json["id"],
    userId: json["user_id"],
    deviceId: json["device_id"],
    logoutStatus: json["logout_status"],
    securityPinStatus: json["security_pin_status"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "device_id": deviceId,
    "logout_status": logoutStatus,
    "security_pin_status": securityPinStatus,
  };
}

class Result {
  String gameId;
  String gameName;
  String gameNameHindi;
  String openTime;
  String openTimeSort;
  String closeTime;
  String gameNameLetter;
  String msg;
  int msgStatus;
  String openResult;
  String closeResult;
  int openDuration;
  int closeDuration;
  int timeSrt;
  String webChartUrl;

  Result({
    required this.gameId,
    required this.gameName,
    required this.gameNameHindi,
    required this.openTime,
    required this.openTimeSort,
    required this.closeTime,
    required this.gameNameLetter,
    required this.msg,
    required this.msgStatus,
    required this.openResult,
    required this.closeResult,
    required this.openDuration,
    required this.closeDuration,
    required this.timeSrt,
    required this.webChartUrl,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
    gameId: json["game_id"],
    gameName: json["game_name"],
    gameNameHindi: json["game_name_hindi"],
    openTime: json["open_time"],
    openTimeSort: json["open_time_sort"],
    closeTime: json["close_time"],
    gameNameLetter: json["game_name_letter"],
    msg: json["msg"],
    msgStatus: json["msg_status"],
    openResult: json["open_result"],
    closeResult: json["close_result"],
    openDuration: json["open_duration"],
    closeDuration: json["close_duration"],
    timeSrt: json["time_srt"],
    webChartUrl: json["web_chart_url"],
  );

  Map<String, dynamic> toJson() => {
    "game_id": gameId,
    "game_name": gameName,
    "game_name_hindi": gameNameHindi,
    "open_time": openTime,
    "open_time_sort": openTimeSort,
    "close_time": closeTime,
    "game_name_letter": gameNameLetter,
    "msg":msg,
    "msg_status": msgStatus,
    "open_result": openResult,
    "close_result": closeResult,
    "open_duration": openDuration,
    "close_duration": closeDuration,
    "time_srt": timeSrt,
    "web_chart_url": webChartUrl,
  };
}






