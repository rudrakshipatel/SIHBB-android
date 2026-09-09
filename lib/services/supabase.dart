import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data.dart';

/// Publishes listings to Supabase using the ANON key only (safe to ship in the
/// client; access is governed by RLS). The service_role key must NEVER be
/// compiled into the app. Uses PostgREST + Storage over plain HTTP so no extra
/// package is needed. Keys come from --dart-define-from-file=secrets.json.
const String _url = String.fromEnvironment('SUPABASE_URL');
const String _anon = String.fromEnvironment('SUPABASE_ANON_KEY');
const String _artisanId = String.fromEnvironment('SUPABASE_ARTISAN_ID',
    defaultValue: '22222222-2222-2222-2222-222222222222');

bool get supabaseConfigured => _url.isNotEmpty && _anon.isNotEmpty;

Map<String, String> get _authHeaders =>
    {'apikey': _anon, 'Authorization': 'Bearer $_anon'};

/// Uploads the photo to Storage and inserts the product (+ image) rows so the
/// listing appears in the Supabase-backed catalogue. Throws on failure; the
/// caller keeps the local (offline) copy regardless.
Future<void> publishToSupabase(Product p) async {
  if (!supabaseConfigured) return;
  final sku = 'HK-${DateTime.now().millisecondsSinceEpoch}';

  // 1) Upload the primary photo to the public bucket.
  String? imageUrl;
  final bytes = p.imageBytes;
  if (bytes != null && bytes.isNotEmpty) {
    final objectPath = 'products/$sku.jpg';
    final up = await http
        .post(
          Uri.parse('$_url/storage/v1/object/product-images/$objectPath'),
          headers: {
            ..._authHeaders,
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));
    if (up.statusCode >= 200 && up.statusCode < 300) {
      imageUrl = '$_url/storage/v1/object/public/product-images/$objectPath';
    }
  }

  // 2) Insert the product row (buyer-facing English description).
  final prodRes = await http
      .post(
        Uri.parse('$_url/rest/v1/products'),
        headers: {
          ..._authHeaders,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'artisan_id': _artisanId,
          'sku': sku,
          'name_en': p.name,
          'name_local': p.nameLocal,
          'category': p.category,
          'description': p.description,
          'cultural_context': p.cultural,
          'materials': p.materials,
          'price': p.price,
          'currency': 'INR',
          'is_b2c': true,
          'status': 'published',
        }),
      )
      .timeout(const Duration(seconds: 60));
  if (prodRes.statusCode < 200 || prodRes.statusCode >= 300) {
    throw Exception('Supabase product insert ${prodRes.statusCode}: ${prodRes.body}');
  }
  final rows = jsonDecode(prodRes.body) as List;
  if (rows.isEmpty) throw Exception('Supabase returned no product row');
  final productId = (rows.first as Map)['id'];

  // 3) Link the uploaded image.
  if (imageUrl != null) {
    await http
        .post(
          Uri.parse('$_url/rest/v1/product_images'),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'product_id': productId,
            'url': imageUrl,
            'is_primary': true,
            'position': 0,
          }),
        )
        .timeout(const Duration(seconds: 60));
  }
}
