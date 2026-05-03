import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/affordability_model.dart';
import 'package:flutter/foundation.dart';

class FredApiService {
  static String get _apiKey => dotenv.env['FRED_API_KEY'] ?? '';
  static const String _seriesId = 'MORTGAGE30US';
  static const String _baseUrl = 'https://api.stlouisfed.org/fred/series/observations';
  static const String _cacheKey = 'fred_mortgage_rates_cache';
  static const String _cacheTimeKey = 'fred_mortgage_rates_cache_time';

  static const double fallbackRate = 6.75;

  Future<List<MortgageRateData>> fetchMortgageRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // 30-minute cache
      if (currentTime - lastCacheTime < 30 * 60 * 1000) {
        final cachedData = prefs.getString(_cacheKey);
        if (cachedData != null) {
          final List<dynamic> decoded = json.decode(cachedData);
          return decoded.map((item) => MortgageRateData.fromJson(item)).toList();
        }
      }

      final url = '$_baseUrl?series_id=$_seriesId&api_key=$_apiKey&file_type=json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> observations = data['observations'];
        
        // Take the last 30 observations for trend analysis
        final List<MortgageRateData> rates = observations
            .reversed
            .take(30)
            .toList()
            .reversed // Re-order back to chronological
            .map((item) => MortgageRateData.fromJson(item))
            .toList();

        // Cache the result
        await prefs.setString(_cacheKey, json.encode(observations.reversed.take(30).toList()));
        await prefs.setInt(_cacheTimeKey, currentTime);

        return rates;
      }
    } catch (e) {
      debugPrint('Error fetching mortgage rates: $e');
    }
    return [];
  }

  double calculateTrend(List<MortgageRateData> rates) {
    if (rates.isEmpty) return 0.0;
    if (rates.length < 2) return 0.0;
    
    final latestValue = rates.last.value;
    final previousValue = rates[rates.length - 2].value;
    return latestValue - previousValue;
  }

  String getTrendStatus(List<MortgageRateData> rates) {
    if (rates.isEmpty) return 'Stable';
    final latestValue = rates.last.value;
    final average = rates.map((r) => r.value).reduce((a, b) => a + b) / rates.length;

    if (latestValue > average) return 'Rising';
    if (latestValue < average) return 'Falling';
    return 'Stable';
  }
}
