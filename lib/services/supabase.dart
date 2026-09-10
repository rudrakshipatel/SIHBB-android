import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data.dart';
import '../theme.dart';
import 'identity.dart';

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
/// Creates/updates this device's artisan (and its user) in Supabase so each
/// installed app publishes as a distinct seller.
Future<void> _ensureArtisan() async {
  final id = identity;
  if (id.artisanId.isEmpty) return;
  final headers = {
    ..._authHeaders,
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates',
  };
  await http
      .post(Uri.parse('$_url/rest/v1/users'),
          headers: headers,
          body: jsonEncode({'id': id.userId, 'role': 'artisan'}))
      .timeout(const Duration(seconds: 30));
  await http
      .post(Uri.parse('$_url/rest/v1/artisans'),
          headers: headers,
          body: jsonEncode({
            'id': id.artisanId,
            'user_id': id.userId,
            'display_name': id.name,
            'slug': 'artisan-${id.artisanId.substring(0, 8)}',
            'location_state': id.location,
            'verification_status': 'verified',
          }))
      .timeout(const Duration(seconds: 30));
}

Future<void> publishToSupabase(Product p) async {
  if (!supabaseConfigured) return;
  await _ensureArtisan();
  final artisanId = identity.artisanId.isNotEmpty ? identity.artisanId : _artisanId;
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
          'artisan_id': artisanId,
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

/// Fetches all published products (with their artisan + primary image) from
/// Supabase, so every device sees listings published from any device.
Future<List<Product>> fetchRemoteProducts() async {
  if (!supabaseConfigured) return const [];
  const select =
      'id,name_en,name_local,category,description,cultural_context,materials,price,'
      'artisans(display_name,location_state,location_district),'
      'product_images(url,is_primary,position)';
  final res = await http
      .get(
        Uri.parse(
            '$_url/rest/v1/products?status=eq.published&select=$select&order=created_at.desc&limit=200'),
        headers: _authHeaders,
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw Exception('Supabase fetch ${res.statusCode}: ${res.body}');
  }
  final list = jsonDecode(res.body) as List;
  return list.map(_mapRow).toList();
}

/// Replaces [remoteProducts] with the latest from Supabase. Best-effort: keeps
/// whatever is already loaded on failure (e.g. offline).
Future<void> refreshRemoteProducts() async {
  try {
    final list = await fetchRemoteProducts();
    remoteProducts
      ..clear()
      ..addAll(list);
  } catch (_) {/* keep current list */}
}

Product _mapRow(dynamic row) {
  final m = row as Map;
  final imgs = (m['product_images'] as List?) ?? const [];
  String? url;
  if (imgs.isNotEmpty) {
    final primary = imgs.firstWhere(
        (e) => (e as Map)['is_primary'] == true,
        orElse: () => imgs.first);
    url = (primary as Map)['url']?.toString();
  }
  final art = m['artisans'] as Map?;
  final loc = [art?['location_district'], art?['location_state']]
      .where((e) => e != null && '$e'.trim().isNotEmpty)
      .join(', ');
  final price = m['price'];
  return Product(
    id: m['id'].toString(),
    name: (m['name_en'] ?? 'Untitled').toString(),
    nameLocal: (m['name_local'] ?? '').toString(),
    price: price is num ? price.round() : (int.tryParse('$price') ?? 0),
    category: (m['category'] ?? '').toString(),
    sub: '',
    artisan: (art?['display_name'] ?? 'Artisan').toString(),
    location: loc.isEmpty ? 'India' : loc,
    description: (m['description'] ?? '').toString(),
    cultural: (m['cultural_context'] ?? '').toString(),
    materials:
        ((m['materials'] as List?) ?? const []).map((e) => e.toString()).toList(),
    c1: AppColors.green,
    c2: AppColors.terracotta,
    imageUrl: url,
  );
}
