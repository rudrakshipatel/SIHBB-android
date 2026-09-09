import 'dart:convert';
import 'dart:typed_data';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
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

/// Gemini (preferred vision provider when its key is compiled in).
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _geminiModel =
    String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.6-flash');

/// True when any live cloud vision key was compiled in via --dart-define.
bool get aiIsLive => _geminiKey.isNotEmpty || _apiKey.isNotEmpty;

/// The engine in use (for display).
String get aiModelLabel => _geminiKey.isNotEmpty
    ? 'Gemini · $_geminiModel'
    : _apiKey.isNotEmpty
        ? 'Claude vision · $_model'
        : 'On-device AI · Google ML Kit (offline, no key)';

/// Craft categories the model must classify into (also the Gemini enum).
const List<String> kCraftCategories = [
  'Textiles, Garments & Embroidery',
  'Ceramics & Pottery',
  'Woodwork & Furniture',
  'Jewellery & Accessories',
  'Decorative Arts & Handicrafts',
  'Miscellaneous',
];

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
  String? imagePath,
  String? craftHint,
  String? location,
  List<Uint8List> moreImages = const [],
}) async {
  // 1) Gemini vision (preferred) when its key was compiled in.
  if (_geminiKey.isNotEmpty) {
    try {
      return await _geminiVision(bytes, mediaType, craftHint, location, moreImages);
    } catch (_) {
      // fall through
    }
  }
  // 2) Claude vision when an Anthropic key was compiled in.
  if (_apiKey.isNotEmpty) {
    try {
      return await _claudeVision(bytes, mediaType, craftHint, location);
    } catch (_) {
      // fall through to on-device / mock so a demo never dead-ends
    }
  }
  // 2) Free, on-device image classification (no key) — genuinely analyses the
  //    photo and picks a category. Skipped only if we have no file path.
  if (imagePath != null) {
    try {
      final r = await _onDeviceLabel(imagePath, craftHint: craftHint, location: location);
      if (r != null) return r;
    } catch (_) {
      // fall through to the deterministic mock
    }
  }
  // 3) Last-resort deterministic mock.
  return _mock(craftHint: craftHint, location: location, bytes: bytes);
}

// ---------------- On-device image labeling (free, offline) ----------------

/// Maps ML Kit label text -> a craft-category profile key. First keyword hit
/// per label contributes that label's confidence to the category's score.
const Map<String, List<String>> _labelMap = {
  'textile': [
    'textile', 'fabric', 'clothing', 'scarf', 'shawl', 'stole', 'dress',
    'embroidery', 'carpet', 'rug', 'wool', 'silk', 'sari', 'saree', 'linen',
    'denim', 'knitting', 'curtain', 'cushion', 'pillow', 'pattern', 'sleeve',
  ],
  'pottery': [
    'pottery', 'vase', 'ceramic', 'bowl', 'porcelain', 'clay', 'earthenware',
    'mug', 'jar', 'plate', 'tableware', 'flowerpot', 'pot',
  ],
  'wood': [
    'wood', 'table', 'furniture', 'chair', 'desk', 'cabinet', 'stool',
    'bench', 'plank', 'hardwood', 'drawer', 'shelf',
  ],
  'jewellery': [
    'jewellery', 'jewelry', 'necklace', 'bracelet', 'earrings', 'earring',
    'ring', 'bead', 'pendant', 'bangle', 'gemstone', 'diamond', 'locket',
    'fashion accessory',
  ],
  'brass': [
    'brass', 'metal', 'bronze', 'copper', 'sculpture', 'figurine', 'statue',
    'bell', 'lamp', 'candle',
  ],
  'decorative': [
    'art', 'painting', 'mirror', 'wall', 'ornament', 'craft', 'decoration',
    'picture frame', 'handicraft', 'still life', 'visual arts',
  ],
};

Future<CatalogResult?> _onDeviceLabel(
  String imagePath, {
  String? craftHint,
  String? location,
}) async {
  final labeler =
      ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.35));
  List<ImageLabel> labels;
  try {
    labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
  } finally {
    await labeler.close();
  }
  if (labels.isEmpty) return null;

  // Score each category by summing the confidence of matching labels.
  final scores = <String, double>{};
  for (final l in labels) {
    final text = l.label.toLowerCase();
    for (final entry in _labelMap.entries) {
      if (entry.value.any((kw) => text.contains(kw))) {
        scores[entry.key] = (scores[entry.key] ?? 0) + l.confidence;
        break;
      }
    }
  }
  String key;
  double conf;
  if (scores.isEmpty) {
    // Nothing mapped to a craft category — treat as miscellaneous decor.
    key = 'decorative';
    conf = labels.first.confidence;
  } else {
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    key = best.key;
    conf = best.value.clamp(0.0, 1.0);
  }
  final top = labels.first.label;
  return _build(
    _profiles[key]!,
    confidence: conf,
    provider: 'on-device (ML Kit)',
    location: location,
    detected: top,
  );
}

// ---------------- Gemini vision provider ----------------

/// Strict JSON schema Gemini must return (OpenAPI subset).
const Map<String, dynamic> _geminiSchema = {
  'type': 'OBJECT',
  'properties': {
    'product_name': {'type': 'STRING'},
    'category': {'type': 'STRING', 'enum': kCraftCategories},
    'craft_type': {'type': 'STRING'},
    'materials': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'colors': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'description': {'type': 'STRING'},
    'cultural_context': {'type': 'STRING'},
    'name_local': {'type': 'STRING'},
    'price_min': {'type': 'INTEGER'},
    'price_max': {'type': 'INTEGER'},
    'tags': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'target_b2c_segments': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'target_b2b_segments': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'recommended_markets': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'confidence': {'type': 'NUMBER'},
    'fields_requiring_confirmation': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
  },
  'required': ['product_name', 'category', 'craft_type', 'description', 'confidence'],
};

Future<CatalogResult> _geminiVision(
  Uint8List bytes,
  String mediaType,
  String? craftHint,
  String? location,
  List<Uint8List> moreImages,
) async {
  final b64 = base64Encode(bytes);
  const sys =
      'You are a cataloging assistant for Indian artisan handicrafts. Look at '
      'the product photo and return a listing that matches the provided JSON '
      'schema. Classify category from the enum. Never invent facts you cannot '
      'see; put uncertain fields in fields_requiring_confirmation. Prices are '
      'fair INR estimates.';
  final user =
      'Craft hint (may be empty): ${craftHint ?? 'unknown'}\n'
      'Artisan location: ${location ?? 'unknown'}\n'
      'Draft the marketplace listing from this photo.';

  final res = await http
      .post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': sys}
            ]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'inline_data': {'mime_type': mediaType, 'data': b64}
                },
                // Additional angles of the same product (up to the caller's cap).
                for (final extra in moreImages)
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Encode(extra)
                    }
                  },
                {'text': user},
              ],
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': _geminiSchema,
            'temperature': 0.4,
          },
        }),
      )
      .timeout(const Duration(seconds: 60));

  if (res.statusCode != 200) {
    throw Exception('Gemini API ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final parts = (((data['candidates'] as List?)?.first
          as Map?)?['content'] as Map?)?['parts'] as List? ??
      const [];
  final text =
      parts.where((p) => p is Map && p['text'] != null).map((p) => p['text'].toString()).join();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('No JSON object in Gemini response');
  }
  final raw = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  return CatalogResult.fromJson(raw, provider: 'gemini');
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
  'jewellery': _Profile(
    'Jewellery & Accessories',
    'Handcrafted Jewellery',
    ['Oxidised metal', 'Beads / stones'],
    ['Silver', 'Gold-tone'],
    800,
    9000,
    ['Ethnic Wear', 'Festive & Wedding'],
    ['Boutique Retail', 'Export Houses'],
    ['Fashion Retail', 'Festive & Wedding', 'Export'],
    'Indian handcrafted jewellery blends regional metalwork with beadwork and '
        'stone-setting traditions.',
    'हस्तनिर्मित आभूषण',
  ),
  'decorative': _Profile(
    'Decorative Arts & Handicrafts',
    'Decorative Handicraft',
    ['Mixed media', 'Natural pigments'],
    ['Earthy tones'],
    900,
    7000,
    ['Home Decor', 'Wall Art'],
    ['Interior Designers', 'Hospitality & Interiors'],
    ['Home Decor Retail', 'Interior Designers', 'Corporate Gifting'],
    'Decorative handicrafts such as Lippan mirror-work and wall art showcase '
        'regional folk-art traditions.',
    'सजावटी शिल्प',
  ),
};

_Profile _pickProfile(String? hint, Uint8List? bytes) {
  final h = (hint ?? '').toLowerCase();
  // 1) Explicit keyword routing from the optional craft hint.
  for (final key in _profiles.keys) {
    if (h.contains(key)) return _profiles[key]!;
  }
  if (h.contains('saree') ||
      h.contains('cloth') ||
      h.contains('fabric') ||
      h.contains('embroid') ||
      h.contains('chikankari') ||
      h.contains('zari') ||
      h.contains('stole') ||
      h.contains('shawl')) {
    return _profiles['textile']!;
  }
  if (h.contains('bowl') || h.contains('vase') || h.contains('clay') || h.contains('terracot')) {
    return _profiles['pottery']!;
  }
  if (h.contains('metal') || h.contains('bird') || h.contains('brass')) {
    return _profiles['brass']!;
  }
  if (h.contains('table') || h.contains('furniture') || h.contains('wood')) {
    return _profiles['wood']!;
  }
  if (h.contains('necklace') || h.contains('earring') || h.contains('jewel') || h.contains('bangle')) {
    return _profiles['jewellery']!;
  }
  if (h.contains('lippan') || h.contains('mirror') || h.contains('wall') || h.contains('decor')) {
    return _profiles['decorative']!;
  }
  // 2) No hint: offline mock can't truly see the image, so vary the category
  //    deterministically by photo content so different photos differ (demo
  //    only — real analysis happens on the live Claude vision path).
  if (bytes != null && bytes.length > 8) {
    final keys = _profiles.keys.toList();
    final sig = bytes.length +
        bytes.first +
        bytes[bytes.length ~/ 3] +
        bytes[bytes.length ~/ 2] +
        bytes[bytes.length - 2];
    return _profiles[keys[sig % keys.length]]!;
  }
  return _profiles['pottery']!;
}

CatalogResult _mock({String? craftHint, String? location, Uint8List? bytes}) =>
    _build(_pickProfile(craftHint, bytes),
        confidence: 0.62, provider: 'mock-v1', location: location);

/// Builds a listing from a craft profile. Shared by the on-device labeler and
/// the deterministic mock. [detected] is the raw label the classifier saw.
CatalogResult _build(
  _Profile p, {
  required double confidence,
  required String provider,
  String? location,
  String? detected,
}) {
  final where = (location == null || location.isEmpty) ? '' : ' from $location';
  final seen = (detected == null || detected.isEmpty)
      ? ''
      : ' The photo was recognised as "$detected".';
  return CatalogResult(
    productName: 'Handcrafted ${p.craftType}',
    category: p.category,
    craftType: p.craftType,
    materials: p.materials,
    colors: p.colors,
    description:
        'A handmade ${p.craftType.toLowerCase()} piece crafted by a skilled '
        'artisan$where.$seen ${p.context}',
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
    confidence: confidence,
    fieldsRequiringConfirmation: const ['price', 'dimensions', 'materials'],
    provider: provider,
  );
}
