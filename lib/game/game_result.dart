// To parse this JSON data, do
//
//     final results = resultsFromJson(jsonString);

import 'dart:convert';

List<Results> resultsFromJson(String str) => List<Results>.from(json.decode(str)["result"].map((x) => Results.fromJson(x)));

String resultsToJson(List<Results> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Results {
  String gameId;
  String gameName;
  String gameNameHindi;
  String openTime;
  String openTimeSort;
  dynamic closeTime;
  String gameNameLetter;
  String msg;

  int msgStatus;
  String openResult;
  String closeResult;
  int openDuration;
  int closeDuration;
  int timeSrt;
  String webChartUrl;

  Results({
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

  factory Results.fromJson(Map<String, dynamic> json) => Results(
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
    "msg": msg,
    "msg_status": msgStatus,
    "open_result": openResult,
    "close_result": closeResult,
    "open_duration": openDuration,
    "close_duration": closeDuration,
    "time_srt": timeSrt,
    "web_chart_url": webChartUrl,

  };
}
