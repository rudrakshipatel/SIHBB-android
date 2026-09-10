import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// "Describe by voice": transcribe an artisan speaking in any of the 22 official
/// Indian languages, and translate to English for the listing.
///
/// Provider order: Bhashini ULCA ASR (when BHASHINI_* keys are compiled in) →
/// Gemini audio (works today with GEMINI_API_KEY, auto-detects the language).
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _geminiModel =
    String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.6-flash');
const String _bhashiniUser = String.fromEnvironment('BHASHINI_USER_ID');
const String _bhashiniKey = String.fromEnvironment('BHASHINI_ULCA_API_KEY');

bool get _bhashiniReady => _bhashiniUser.isNotEmpty && _bhashiniKey.isNotEmpty;

/// True when voice transcription can run (any provider available).
bool get voiceIsLive => _bhashiniReady || _geminiKey.isNotEmpty;

/// Which engine will be used, for display.
String get voiceEngineLabel => _bhashiniReady
    ? 'Bhashini ASR'
    : _geminiKey.isNotEmpty
        ? 'Gemini audio'
        : 'unavailable';

class VoiceResult {
  final String transcript; // original language + script
  final String transcriptEn; // English translation
  final String language; // detected language (name)
  const VoiceResult(this.transcript, this.transcriptEn, this.language);
}

/// Transcribe recorded audio. [mime] must match the recording (default WAV).
Future<VoiceResult> transcribeVoice(Uint8List audio,
    {String mime = 'audio/wav'}) async {
  // Bhashini ULCA path drops in here once BHASHINI_* keys are provided.
  return _geminiTranscribe(audio, mime);
}

Future<VoiceResult> _geminiTranscribe(Uint8List audio, String mime) async {
  if (_geminiKey.isEmpty) {
    throw StateError('No transcription provider configured');
  }
  final b64 = base64Encode(audio);
  const sys =
      'You transcribe an Indian artisan describing their handmade product. The '
      'speaker may use any of the 22 official Indian languages. Return JSON only.';
  const prompt =
      'Transcribe the speech verbatim in its original language and script, '
      'translate it to natural English, and name the language. If there is no '
      'clear speech, return empty strings.';
  const schema = {
    'type': 'OBJECT',
    'properties': {
      'transcript': {'type': 'STRING'},
      'transcript_en': {'type': 'STRING'},
      'language': {'type': 'STRING'},
    },
    'required': ['transcript', 'transcript_en', 'language'],
  };

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
                  'inline_data': {'mime_type': mime, 'data': b64}
                },
                {'text': prompt},
              ],
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': schema,
            'temperature': 0.2,
            'thinkingConfig': {'thinkingLevel': 'low'},
          },
        }),
      )
      .timeout(const Duration(seconds: 60));

  if (res.statusCode != 200) {
    throw Exception('Gemini audio ${res.statusCode}: ${res.body}');
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
  if (s < 0 || e <= s) throw const FormatException('No JSON in Gemini response');
  final j = jsonDecode(text.substring(s, e + 1)) as Map<String, dynamic>;
  return VoiceResult(
    (j['transcript'] ?? '').toString(),
    (j['transcript_en'] ?? '').toString(),
    (j['language'] ?? '').toString(),
  );
}
