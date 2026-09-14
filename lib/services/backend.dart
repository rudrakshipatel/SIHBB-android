import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data.dart';
import '../theme.dart';

/// FastAPI backend (Python + PostgreSQL) integration. When BACKEND_URL is
/// compiled in (via secrets.json), the buyer catalogue is served by the
/// FastAPI service instead of Supabase. Example:
///   BACKEND_URL = http://192.168.1.50:8000/api/v1
const String backendUrl = String.fromEnvironment('BACKEND_URL');

bool get backendConfigured => backendUrl.isNotEmpty;

/// Fetches the published catalogue from the FastAPI backend
/// (GET /catalog/products) and maps it to [Product].
Future<List<Product>> fetchBackendCatalog({int limit = 60}) async {
  final res = await http
      .get(Uri.parse('$backendUrl/catalog/products?limit=$limit'))
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw Exception('Backend catalogue ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final list = (data['products'] as List?) ?? const [];
  return list.map(_mapProduct).toList();
}

Product _mapProduct(dynamic row) {
  final m = row as Map;
  final art = m['artisan'] as Map?;
  final price = m['price_amount'];
  return Product(
    id: m['id'].toString(),
    name: (m['title'] ?? 'Untitled').toString(),
    nameLocal: (m['title_local'] ?? '').toString(),
    price: price is num ? price.round() : (int.tryParse('$price') ?? 0),
    category: (m['category'] ?? '').toString(),
    sub: '',
    artisan: (art?['name'] ?? 'Artisan').toString(),
    location: (art?['location'] ?? 'India').toString(),
    description: (m['description'] ?? '').toString(),
    cultural: (m['cultural_context'] ?? '').toString(),
    materials: ((m['materials'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    c1: AppColors.green,
    c2: AppColors.terracotta,
    imageUrl: m['image_url']?.toString(),
  );
}
