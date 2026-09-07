import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// AI product-cataloging from a photo. Provider-abstracted, mirroring the web
/// app's ai.ts: a deterministic mock (default — works offline and drives
/// reliable demos) and a Claude vision adapter enabled by an --dart-define'd
/// ANTHROPIC_API_KEY. Model output is always coerced into [CatalogResult]
/// before it reaches the UI, and a failed live call falls back to the mock so
/// a demo never dead-ends.
///
/// Build with the live model like this (the key is never hardcoded in source):
///   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
///   flutter build apk --debug --dart-define=ANTHROPIC_API_KEY=sk-ant-... \
///       --dart-define=AI_MODEL=claude-sonnet-5
const String _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const String _model =
    String.fromEnvironment('AI_MODEL', defaultValue: 'claude-opus-5');

/// True when a live Anthropic key was compiled in via --dart-define.
bool get aiIsLive => _apiKey.isNotEmpty;

/// The model id in use (for display), or 'demo' in offline mock mode.
String get aiModelLabel => aiIsLive ? _model : 'demo (offline mock)';

class CatalogResult {
  final String productName;
  final String category;
  final String craftType;
  final List<String> materials;
  final List<String> colors;
  final String description;
  final String culturalContext;
  final String nameLocal;
  final int? priceMin;
  final int? priceMax;
  final List<String> tags;
  final List<String> b2cSegments;
  final List<String> b2bSegments;
  final List<String> recommendedMarkets;
  final double confidence;
  final List<String> fieldsRequiringConfirmation;

  /// 'claude' for a live vision result, 'mock-v1' for the offline demo.
  final String provider;

  const CatalogResult({
    required this.productName,
    required this.category,
    required this.craftType,
    required this.materials,
    required this.colors,
    required this.description,
    required this.culturalContext,
    required this.nameLocal,
    required this.priceMin,
    required this.priceMax,
    required this.tags,
    required this.b2cSegments,
    required this.b2bSegments,
    required this.recommendedMarkets,
    required this.confidence,
    required this.fieldsRequiringConfirmation,
    required this.provider,
  });

  factory CatalogResult.fromJson(Map<String, dynamic> j,
      {required String provider}) {
    List<String> strList(dynamic v) => v is List
        ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const [];
    int? asInt(dynamic v) =>
        v is num ? v.round() : (v is String ? int.tryParse(v) : null);
    return CatalogResult(
      productName: (j['product_name'] ?? 'Untitled craft').toString(),
      category: (j['category'] ?? 'Decorative Arts & Handicrafts').toString(),
      craftType: (j['craft_type'] ?? 'Handicraft').toString(),
      materials: strList(j['materials']),
      colors: strList(j['colors']),
      description: (j['description'] ?? '').toString(),
      culturalContext: (j['cultural_context'] ?? '').toString(),
      nameLocal: (j['name_local'] ?? '').toString(),
      priceMin: asInt(j['price_min']),
      priceMax: asInt(j['price_max']),
      tags: strList(j['tags']),
      b2cSegments: strList(j['target_b2c_segments']),
      b2bSegments: strList(j['target_b2b_segments']),
      recommendedMarkets: strList(j['recommended_markets']),
      confidence: (j['confidence'] is num)
          ? (j['confidence'] as num).toDouble().clamp(0, 1).toDouble()
          : 0.6,
      fieldsRequiringConfirmation: strList(j['fields_requiring_confirmation']),
      provider: provider,
    );
  }
}

/// Understand a product photo and return a structured catalog listing.
/// Falls back to the deterministic mock on any live-call failure.
Future<CatalogResult> generateCatalogFromPhoto(
  Uint8List bytes, {
  String mediaType = 'image/jpeg',
  String? craftHint,
  String? location,
}) async {
  if (!aiIsLive) {
    return _mock(craftHint: craftHint, location: location);
  }
  try {
    return await _claudeVision(bytes, mediaType, craftHint, location);
  } catch (_) {
    // Never dead-end a live demo — fall back to the deterministic mock.
    return _mock(craftHint: craftHint, location: location);
  }
}

// ---------------- Claude vision provider ----------------

Future<CatalogResult> _claudeVision(
  Uint8List bytes,
  String mediaType,
  String? craftHint,
  String? location,
) async {
  final b64 = base64Encode(bytes);
  const sys =
      'You are a cataloging assistant for Indian artisan handicrafts. Look at '
      'the product photo and return ONLY a JSON object (no prose, no markdown '
      'fences) matching the requested schema. Never invent facts you cannot '
      'see in the image; if unsure about a field, include its name in '
      'fields_requiring_confirmation.';
  final user =
      'Identify this handmade craft from the photo and draft a marketplace '
      'listing for an Indian artisan.\n'
      'Craft hint (may be empty): ${craftHint ?? 'unknown'}\n'
      'Artisan location: ${location ?? 'unknown'}\n'
      'Return a JSON object with keys: product_name, category, craft_type, '
      'materials (array), colors (array), description, cultural_context, '
      'name_local (a short name in Hindi/Devanagari), price_min (fair INR '
      'integer), price_max (INR integer), tags (array), target_b2c_segments '
      '(array), target_b2b_segments (array), recommended_markets (array), '
      'confidence (0..1), fields_requiring_confirmation (array of key names).';

  final res = await http
      .post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'content-type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1200,
          'output_config': {'effort': 'low'},
          'system': sys,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mediaType,
                    'data': b64,
                  },
                },
                {'type': 'text', 'text': user},
              ],
            },
          ],
        }),
      )
      .timeout(const Duration(seconds: 60));

  if (res.statusCode != 200) {
    throw Exception('Anthropic API ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final blocks = (data['content'] as List?) ?? const [];
  final text = blocks
      .where((b) => b is Map && b['type'] == 'text')
      .map((b) => b['text'].toString())
      .join();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('No JSON object in model response');
  }
  final raw = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  return CatalogResult.fromJson(raw, provider: 'claude');
}

// ---------------- Mock provider (deterministic, offline) ----------------

class _Profile {
  final String category;
  final String craftType;
  final List<String> materials;
  final List<String> colors;
  final int priceMin;
  final int priceMax;
  final List<String> b2c;
  final List<String> b2b;
  final List<String> markets;
  final String context;
  final String nameLocal;
  const _Profile(this.category, this.craftType, this.materials, this.colors,
      this.priceMin, this.priceMax, this.b2c, this.b2b, this.markets,
      this.context, this.nameLocal);
}

const _profiles = <String, _Profile>{
  'pottery': _Profile(
    'Ceramics & Pottery',
    'Terracotta Pottery',
    ['Natural terracotta clay', 'Natural pigments'],
    ['Terracotta', 'Ochre'],
    600,
    2200,
    ['Home Decor', 'Festival & Pooja'],
    ['Corporate Gifting', 'Retail Boutiques'],
    ['Home Decor Retail', 'Eco Craft Stores', 'Corporate Gifting'],
    'Terracotta is one of India\'s oldest craft traditions, valued for its '
        'eco-friendly, hand-moulded character.',
    'मिट्टी का शिल्प',
  ),
  'textile': _Profile(
    'Textiles, Garments & Embroidery',
    'Handloom Weaving',
    ['Handspun cotton', 'Natural dyes'],
    ['Indigo', 'Maroon'],
    1200,
    6500,
    ['Ethnic Wear', 'Sustainable Fashion'],
    ['Boutique Retail', 'Export Houses'],
    ['Boutique Retail', 'Sustainable Fashion', 'Export'],
    'Indian handloom carries centuries-old regional motifs and supports rural '
        'weaver families.',
    'हस्तनिर्मित वस्त्र',
  ),
  'brass': _Profile(
    'Decorative Arts & Handicrafts',
    'Brass Metalware',
    ['Brass alloy'],
    ['Golden brass'],
    1500,
    3500,
    ['Home Decor', 'Pooja & Rituals'],
    ['Hospitality & Interiors', 'Corporate Gifting'],
    ['Hospitality & Interiors', 'Home Decor Retail', 'Corporate Gifting'],
    'Brass metalware is central to Indian rituals and celebrated in '
        'Moradabad\'s engraving tradition.',
    'पीतल शिल्प',
  ),
  'wood': _Profile(
    'Woodwork & Furniture',
    'Hand-carved Woodwork',
    ['Seasoned hardwood'],
    ['Natural brown'],
    8000,
    60000,
    ['Home Decor', 'Premium Furniture'],
    ['Interior Designers', 'Boutique Hotels'],
    ['Premium Home Decor', 'Heritage Furniture', 'Interior Designers'],
    'Hand-carved wood furniture reflects regional relief-carving traditions '
        'prized in luxury interiors.',
    'काष्ठ शिल्प',
  ),
};

_Profile _pickProfile(String? hint) {
  final h = (hint ?? '').toLowerCase();
  for (final key in _profiles.keys) {
    if (h.contains(key)) return _profiles[key]!;
  }
  if (h.contains('saree') || h.contains('cloth') || h.contains('embroid')) {
    return _profiles['textile']!;
  }
  if (h.contains('bowl') || h.contains('vase') || h.contains('clay')) {
    return _profiles['pottery']!;
  }
  if (h.contains('metal') || h.contains('bird')) return _profiles['brass']!;
  if (h.contains('table') || h.contains('furniture')) {
    return _profiles['wood']!;
  }
  return _profiles['pottery']!;
}

CatalogResult _mock({String? craftHint, String? location}) {
  final p = _pickProfile(craftHint);
  final where = (location == null || location.isEmpty) ? '' : ' from $location';
  return CatalogResult(
    productName: 'Handcrafted ${p.craftType}',
    category: p.category,
    craftType: p.craftType,
    materials: p.materials,
    colors: p.colors,
    description:
        'A handmade ${p.craftType.toLowerCase()} piece crafted by a skilled '
        'artisan$where. ${p.context}',
    culturalContext: p.context,
    nameLocal: p.nameLocal,
    priceMin: p.priceMin,
    priceMax: p.priceMax,
    tags: [
      p.craftType.toLowerCase().split(' ').first,
      'handmade',
      'artisan',
    ],
    b2cSegments: p.b2c,
    b2bSegments: p.b2b,
    recommendedMarkets: p.markets,
    confidence: 0.62,
    fieldsRequiringConfirmation: const ['price', 'dimensions', 'materials'],
    provider: 'mock-v1',
  );
}
