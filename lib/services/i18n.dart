import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'store.dart';

/// Runtime localization for the whole app into any of the 22 official Indian
/// languages. UI strings are wrapped with `t('English')`; when a non-English
/// language is active, strings are translated in batches via Gemini and cached
/// in SQLite (so later loads are instant + offline). Unknown strings render in
/// English until their batch returns, then the UI rebuilds.
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _geminiModel = String.fromEnvironment('GEMINI_MODEL',
    defaultValue: 'gemini-flash-lite-latest');

class Lang {
  final String name; // English name
  final String code; // ISO code (cache key)
  final String native; // endonym shown in the picker
  const Lang(this.name, this.code, this.native);
}

/// English + the 22 languages in the 8th Schedule of the Constitution.
const List<Lang> kLanguages = [
  Lang('English', 'en', 'English'),
  Lang('Hindi', 'hi', 'हिन्दी'),
  Lang('Bengali', 'bn', 'বাংলা'),
  Lang('Telugu', 'te', 'తెలుగు'),
  Lang('Marathi', 'mr', 'मराठी'),
  Lang('Tamil', 'ta', 'தமிழ்'),
  Lang('Urdu', 'ur', 'اردو'),
  Lang('Gujarati', 'gu', 'ગુજરાતી'),
  Lang('Kannada', 'kn', 'ಕನ್ನಡ'),
  Lang('Odia', 'or', 'ଓଡ଼ିଆ'),
  Lang('Malayalam', 'ml', 'മലയാളം'),
  Lang('Punjabi', 'pa', 'ਪੰਜਾਬੀ'),
  Lang('Assamese', 'as', 'অসমীয়া'),
  Lang('Maithili', 'mai', 'मैथिली'),
  Lang('Santali', 'sat', 'ᱥᱟᱱᱛᱟᱲᱤ'),
  Lang('Kashmiri', 'ks', 'کٲشُر'),
  Lang('Nepali', 'ne', 'नेपाली'),
  Lang('Konkani', 'kok', 'कोंकणी'),
  Lang('Sindhi', 'sd', 'سنڌي'),
  Lang('Dogri', 'doi', 'डोगरी'),
  Lang('Manipuri', 'mni', 'ꯃꯤꯇꯩꯂ'),
  Lang('Bodo', 'brx', 'बड़ो'),
  Lang('Sanskrit', 'sa', 'संस्कृतम्'),
];

class AppLocale extends ChangeNotifier {
  Lang _lang = kLanguages.first;
  final Map<String, String> _dict = {};
  final Set<String> _pending = {};
  Timer? _flush;

  Lang get lang => _lang;
  bool get isEnglish => _lang.code == 'en';

  /// Translate a UI string to the active language (English passes through).
  String t(String en) {
    if (isEnglish || en.trim().isEmpty) return en;
    final hit = _dict[en];
    if (hit != null) return hit;
    _pending.add(en);
    _scheduleFlush();
    return en; // show English until the batch returns
  }

  /// Restore the saved language + cached dictionary at startup.
  Future<void> load() async {
    final code = await getSetting('app_lang_code');
    if (code == null) return;
    _lang = kLanguages.firstWhere((l) => l.code == code,
        orElse: () => kLanguages.first);
    await _loadCache();
  }

  Future<void> setLanguage(Lang l) async {
    _lang = l;
    _dict.clear();
    _pending.clear();
    await setSetting('app_lang_code', l.code);
    await _loadCache();
    notifyListeners();
  }

  Future<void> _loadCache() async {
    if (isEnglish) return;
    final cached = await getSetting('i18n_${_lang.code}');
    if (cached == null) return;
    try {
      (jsonDecode(cached) as Map)
          .forEach((k, v) => _dict[k.toString()] = v.toString());
    } catch (_) {}
  }

  void _scheduleFlush() {
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 450), _flushNow);
  }

  Future<void> _flushNow() async {
    if (isEnglish || _pending.isEmpty || _geminiKey.isEmpty) {
      _pending.clear();
      return;
    }
    final batch = _pending.toList();
    _pending.clear();
    try {
      final out = await _translate(batch, _lang);
      var changed = false;
      out.forEach((k, v) {
        if (v.trim().isNotEmpty) {
          _dict[k] = v;
          changed = true;
        }
      });
      if (changed) {
        await setSetting('i18n_${_lang.code}', jsonEncode(_dict));
        notifyListeners();
      }
    } catch (_) {
      // leave the strings in English on failure
    }
  }

  Future<Map<String, String>> _translate(List<String> items, Lang l) async {
    final sys =
        'You are a UI localizer for an Indian artisan marketplace mobile app. '
        'Translate each given English UI string into ${l.name} (${l.native}). '
        'Keep translations short and natural for buttons/labels. Preserve '
        'numbers, currency symbols like ₹, hashtags, and punctuation. Return '
        'ONLY a JSON object mapping each exact input string to its translation.';
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
                  {'text': jsonEncode(items)}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.2,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('i18n API ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = (((data['candidates'] as List?)?.first
            as Map?)?['content'] as Map?)?['parts'] as List? ??
        const [];
    final text = parts
        .where((p) => p is Map && p['text'] != null)
        .map((p) => p['text'].toString())
        .join();
    final s = text.indexOf('{');
    final e = text.lastIndexOf('}');
    if (s < 0 || e <= s) throw const FormatException('no json');
    final map = jsonDecode(text.substring(s, e + 1)) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  }
}

/// Global instance + shorthand.
final AppLocale appLocale = AppLocale();
String t(String en) => appLocale.t(en);

/// Wrap a screen's build so it rebuilds when the language changes (or when a
/// translation batch finishes). Usage: `Localized((context) => Scaffold(...))`.
class Localized extends StatelessWidget {
  final WidgetBuilder child;
  const Localized(this.child, {super.key});
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: appLocale, builder: (c, _) => child(c));
}
