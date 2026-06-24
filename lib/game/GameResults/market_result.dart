class MarketResult {
  final String market;
  final String result;

  MarketResult({
    required this.market,
    required this.result,
  });

  factory MarketResult.fromJson(Map<String, dynamic> json) {
    return MarketResult(
      market: json['market_name'] ?? 'Unknown',
      result: json['result'] ?? '***-**-**',
    );
  }
}
