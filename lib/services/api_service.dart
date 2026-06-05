import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MortgageLenderData {
  final String name;
  final String logoUrl;
  final String website;
  final List<String> loanTypes;
  final double rateAdjustment;
  final double aprAdjustment;
  final int estimatedFees;
  final int? closingCosts;

  MortgageLenderData({
    required this.name,
    required this.logoUrl,
    required this.website,
    required this.loanTypes,
    required this.rateAdjustment,
    required this.aprAdjustment,
    required this.estimatedFees,
    this.closingCosts,
  });

  factory MortgageLenderData.fromJson(Map<String, dynamic> json) {
    return MortgageLenderData(
      name: json['name']?.toString() ?? '',
      logoUrl: json['logo']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      loanTypes: json['loan_types'] != null
          ? List<String>.from(json['loan_types'])
          : [],
      rateAdjustment: (json['rate_adjustment'] ?? 0).toDouble(),
      aprAdjustment: (json['apr_adjustment'] ?? 0).toDouble(),
      estimatedFees: (json['estimated_fees'] ?? 0).toInt(),
      closingCosts: json['closing_costs']?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MortgageLenderData &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class CityData {
  final String city;
  final String state;
  final int population;
  final int medianPrice;
  final int pricePerSqft;
  final int medianRent;
  final double propertyTaxRate;
  final double costOfLivingIndex;
  final double growthIndex;
  final double demandScore;
  final double crimeRateIndex;
  final double schoolRating;
  final double livabilityScore;
  final String rating;
  final String description;
  final String imageUrl;
  final int daysOnMarket;
  final int inventory;

  CityData({
    required this.city,
    required this.state,
    required this.population,
    required this.medianPrice,
    required this.pricePerSqft,
    required this.medianRent,
    required this.propertyTaxRate,
    required this.costOfLivingIndex,
    required this.growthIndex,
    required this.demandScore,
    required this.crimeRateIndex,
    required this.schoolRating,
    required this.livabilityScore,
    required this.rating,
    required this.description,
    required this.imageUrl,
    required this.daysOnMarket,
    required this.inventory,
  });

  factory CityData.fromJson(Map<String, dynamic> json) {
    return CityData(
      city: json['city']?.toString() ?? 'Unknown',
      state: json['state']?.toString() ?? '',
      population: (json['population'] ?? 0).toInt(),
      medianPrice: (json['median_price'] ?? 0).toInt(),
      pricePerSqft: (json['price_per_sqft'] ?? 0).toInt(),
      medianRent: (json['median_rent'] ?? 0).toInt(),
      propertyTaxRate: (json['property_tax_rate'] ?? 0).toDouble(),
      costOfLivingIndex: (json['cost_of_living_index'] ?? 0).toDouble(),
      growthIndex: (json['growth_index'] ?? 0).toDouble(),
      demandScore: (json['demand_score'] ?? 0).toDouble(),
      crimeRateIndex: (json['crime_rate_index'] ?? 0).toDouble(),
      schoolRating: (json['school_rating'] ?? 0).toDouble(),
      livabilityScore: (json['livability_score'] ?? 0).toDouble(),
      rating: json['rating']?.toString() ?? 'N/A',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      daysOnMarket: (json['days_on_market'] ?? 0).toInt(),
      inventory: (json['inventory'] ?? 0).toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityData &&
          runtimeType == other.runtimeType &&
          city == other.city &&
          state == other.state;

  @override
  int get hashCode => city.hashCode ^ (state.hashCode);
}

class ApisService {
  static const String lendersUrl =
      'https://raw.githubusercontent.com/raheemreo/Mortgage-Calculator-pro/main/lenders.json';
  static const String cityPricesUrl =
      'https://raw.githubusercontent.com/raheemreo/Mortgage-Calculator-pro/main/price_by_cities.json';
  static const String propertyTaxUrl =
      'https://raw.githubusercontent.com/raheemreo/Mortgage-Calculator-pro/main/property_tax.json';

  // FRED API
  static String get liveRatesUrl {
    final apiKey = dotenv.env['FRED_API_KEY'] ?? '';
    return 'https://api.stlouisfed.org/fred/series/observations'
        '?series_id=MORTGAGE30US&api_key=$apiKey&file_type=json&sort_order=desc&limit=5';
  }

  Future<List<MortgageLenderData>> getLenders() async {
    try {
      final response = await http
          .get(Uri.parse(lendersUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('lenders')) {
          final List<dynamic> lendersJson = data['lenders'];
          return lendersJson
              .map((json) => MortgageLenderData.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint(
        'Error fetching lenders from remote: $e. Falling back to local assets.',
      );
    }

    try {
      final String localData = await rootBundle.loadString(
        'assets/data/lenders.json',
      );
      final Map<String, dynamic> data = json.decode(localData);
      if (data.containsKey('lenders')) {
        final List<dynamic> lendersJson = data['lenders'];
        return lendersJson
            .map((json) => MortgageLenderData.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint(
        'Error loading local lenders asset: $e. Using code-level fallback.',
      );
    }

    // Code-level fallback (Triple Fallback)
    return [
      MortgageLenderData(
        name: 'Rocket Mortgage',
        logoUrl: 'https://logo.clearbit.com/rocketmortgage.com',
        website: 'https://www.rocketmortgage.com',
        loanTypes: ['30-Year Fixed', '15-Year Fixed', 'Refinance'],
        rateAdjustment: 0.0,
        aprAdjustment: 0.1,
        estimatedFees: 2100,
      ),
      MortgageLenderData(
        name: 'Wells Fargo',
        logoUrl: 'https://logo.clearbit.com/wellsfargo.com',
        website: 'https://www.wellsfargo.com',
        loanTypes: ['30-Year Fixed', 'FHA', 'VA'],
        rateAdjustment: 0.05,
        aprAdjustment: 0.15,
        estimatedFees: 1950,
      ),
    ];
  }

  Future<List<CityData>> getCityPrices() async {
    try {
      final response = await http
          .get(Uri.parse(cityPricesUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('home_prices_by_city')) {
          final List<dynamic> citiesJson = data['home_prices_by_city'];
          return citiesJson.map((json) => CityData.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint(
        'Error fetching city prices from remote: $e. Falling back to local assets.',
      );
    }

    try {
      final String localData = await rootBundle.loadString(
        'assets/data/price_by_cities.json',
      );
      final Map<String, dynamic> data = json.decode(localData);
      if (data.containsKey('home_prices_by_city')) {
        final List<dynamic> citiesJson = data['home_prices_by_city'];
        return citiesJson.map((json) => CityData.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint(
        'Error loading local city prices asset: $e. Using code-level fallback.',
      );
    }

    // Code-level fallback with the new required fields
    return [
      CityData(
        city: 'New York',
        state: 'NY',
        population: 8336817,
        medianPrice: 650000,
        pricePerSqft: 720,
        medianRent: 3400,
        propertyTaxRate: 0.88,
        costOfLivingIndex: 187.2,
        growthIndex: 8.5,
        demandScore: 9.2,
        crimeRateIndex: 48.0,
        schoolRating: 8.5,
        livabilityScore: 8.4,
        rating: 'A',
        description:
            'Major global financial center with high housing demand and strong property values.',
        imageUrl:
            'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9',
        daysOnMarket: 45,
        inventory: 21000,
      ),
      CityData(
        city: 'Los Angeles',
        state: 'CA',
        population: 3898747,
        medianPrice: 850000,
        pricePerSqft: 810,
        medianRent: 2900,
        propertyTaxRate: 0.73,
        costOfLivingIndex: 173.3,
        growthIndex: 9.1,
        demandScore: 9.5,
        crimeRateIndex: 52.5,
        schoolRating: 8.1,
        livabilityScore: 8.1,
        rating: 'A+',
        description:
            'Entertainment capital with a competitive housing market and strong property appreciation.',
        imageUrl:
            'https://images.unsplash.com/photo-1518569656558-1fdc1a6b4a62',
        daysOnMarket: 30,
        inventory: 15000,
      ),
    ];
  }

  Future<Map<String, double>> getPropertyTaxes() async {
    try {
      final response = await http
          .get(Uri.parse(propertyTaxUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('property_tax_rates')) {
          final Map<String, dynamic> ratesJson = data['property_tax_rates'];
          return ratesJson.map((key, value) => MapEntry(key, value.toDouble()));
        }
      }
    } catch (e) {
      debugPrint(
        'Error fetching property taxes from remote: $e. Falling back to local assets.',
      );
    }

    try {
      final String localData = await rootBundle.loadString(
        'assets/data/property_tax.json',
      );
      final Map<String, dynamic> data = json.decode(localData);
      if (data.containsKey('property_tax_rates')) {
        final Map<String, dynamic> ratesJson = data['property_tax_rates'];
        return ratesJson.map((key, value) => MapEntry(key, value.toDouble()));
      }
    } catch (e) {
      debugPrint(
        'Error loading local property tax asset: $e. Using fixed map.',
      );
    }

    return {'California': 0.72, 'Texas': 1.6, 'Florida': 0.8, 'New York': 1.4};
  }

  Future<List<Map<String, dynamic>>> getLiveRates() async {
    try {
      final response = await http
          .get(Uri.parse(liveRatesUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('observations')) {
          return List<Map<String, dynamic>>.from(data['observations']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching live rates: $e');
    }
    return [];
  }

  Future<Map<String, double>?> getCoordinates(String city, String state) async {
    try {
      final query = Uri.encodeComponent('$city, $state');
      final url =
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'MortgageCalculatorApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
          };
        }
      }
    } catch (e) {
      // print('Error geocoding: $e');
    }
    return null;
  }
}
