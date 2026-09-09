import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:record/record.dart';

import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import '../services/ai_camera.dart';
import '../services/store.dart';
import '../services/voice.dart';

/// One captured product photo (1–3 allowed per listing).
class _Photo {
  final Uint8List bytes;
  final String path;
  final String mediaType;
  final bool cutout;
  final double? sharpness;
  const _Photo(this.bytes, this.path, this.mediaType,
      {this.cutout = false, this.sharpness});
}

/// AI camera cataloging: 1–3 photos + an optional spoken description, sent to
/// the AI to build an editable listing.
class AiCameraScreen extends StatefulWidget {
  const AiCameraScreen({super.key});
  @override
  State<AiCameraScreen> createState() => _AiCameraScreenState();
}

class _AiCameraScreenState extends State<AiCameraScreen> {
  // Suggested-price formula (transparent + editable by the artisan).
  // P_floor = round50( (C_raw + t*w + O) * (1 + m) ),  O = k * C_raw
  static const double _wagePerHour = 35; // w: ₹ artisan labour per hour
  static const double _margin = 0.25; // m: fair profit margin
  static const double _overheadRate = 0.10; // k: packaging/power/wastage on C_raw
  static const int _maxPhotos = 3;
  static const double _blurWarn = 100; // variance-of-Laplacian warn threshold

  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _desc = TextEditingController(); // artisan's description (their language)
  final _materials = TextEditingController();
  final _rawCost = TextEditingController();
  final _hours = TextEditingController();
  final _rate = TextEditingController();
  final _inventory = TextEditingController();
  final _price = TextEditingController();
  final _tags = TextEditingController();

  final List<_Photo> _photos = [];
  String _descEn = ''; // English version shown to buyers
  bool _descLocal = false; // true when _desc holds a non-English language
  bool _cutoutBusy = false;
  CatalogResult? _result;
  bool _busy = false;

  // Describe-by-voice state.
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _transcribing = false;
  VoiceResult? _voice;

  _Photo? get _primary => _photos.isEmpty ? null : _photos.first;
  bool get _isBlurry =>
      _primary?.sharpness != null && _primary!.sharpness! < _blurWarn;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _materials.dispose();
    _rawCost.dispose();
    _hours.dispose();
    _rate.dispose();
    _inventory.dispose();
    _price.dispose();
    _tags.dispose();
    _recorder.dispose();
    super.dispose();
  }

  double get _wage => double.tryParse(_rate.text.trim()) ?? _wagePerHour;

  // ---------------- Photos (1–3) ----------------

  Future<void> _appendXFile(XFile x) async {
    final bytes = await x.readAsBytes();
    final p = x.path.toLowerCase();
    final mt = p.endsWith('.png')
        ? 'image/png'
        : p.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    if (!mounted) return;
    setState(() {
      _photos.add(_Photo(bytes, x.path, mt, sharpness: _computeSharpness(bytes)));
      _result = null; // photos changed → needs re-analysis
    });
  }

  Future<void> _addFromCamera() async {
    if (_photos.length >= _maxPhotos) return;
    try {
      final x = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 1280, imageQuality: 85);
      if (x != null) await _appendXFile(x);
    } catch (e) {
      _toast('Could not open the camera: $e');
    }
  }

  Future<void> _addFromGallery() async {
    if (_photos.length >= _maxPhotos) return;
    try {
      final xs =
          await _picker.pickMultiImage(maxWidth: 1280, imageQuality: 85);
      for (final x in xs) {
        if (_photos.length >= _maxPhotos) break;
        await _appendXFile(x);
      }
    } catch (e) {
      _toast('Could not open the gallery: $e');
    }
  }

  void _removePhoto(int i) => setState(() {
        _photos.removeAt(i);
        _result = null;
      });

  double _computeSharpness(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return _blurWarn;
    final g = img.grayscale(img.copyResize(decoded, width: 320));
    final w = g.width, h = g.height;
    double lum(int x, int y) => g.getPixel(x, y).r.toDouble();
    double sum = 0, sumSq = 0;
    int n = 0;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final lap = 4 * lum(x, y) -
            lum(x - 1, y) -
            lum(x + 1, y) -
            lum(x, y - 1) -
            lum(x, y + 1);
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n == 0) return _blurWarn;
    final mean = sum / n;
    return sumSq / n - mean * mean;
  }

  /// On-device background removal for the main (first) photo.
  Future<void> _removeBackground() async {
    final primary = _primary;
    if (primary == null || _cutoutBusy || primary.cutout) return;
    setState(() => _cutoutBusy = true);
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
            enableConfidenceMask: false, enableSubjectBitmap: false),
      ),
    );
    try {
      final result =
          await segmenter.processImage(InputImage.fromFilePath(primary.path));
      final fg = result.foregroundBitmap;
      final fgImg = fg == null ? null : img.decodeImage(fg);
      if (fgImg == null) throw Exception('no subject detected');
      final canvas = img.Image(width: fgImg.width, height: fgImg.height);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, fgImg);
      final out = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
      final tmp = File(
          '${Directory.systemTemp.path}/cutout_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tmp.writeAsBytes(out);
      if (!mounted) return;
      setState(() {
        _photos[0] = _Photo(out, tmp.path, 'image/jpeg',
            cutout: true, sharpness: _computeSharpness(out));
      });
    } catch (e) {
      _toast("Couldn't remove background: $e");
    } finally {
      await segmenter.close();
      if (mounted) setState(() => _cutoutBusy = false);
    }
  }

  // ---------------- Voice (any of 22 Indian languages) ----------------

  /// Records the spoken description and transcribes it. The artisan's own
  /// language is kept in the editable field; the English translation is what
  /// buyers see.
  Future<void> _toggleVoice() async {
    if (_transcribing) return;
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _transcribing = true;
      });
      try {
        if (path == null) throw Exception('no audio captured');
        final bytes = await File(path).readAsBytes();
        final v = await transcribeVoice(bytes, mime: 'audio/wav');
        if (!mounted) return;
        setState(() {
          _voice = v;
          final en = v.transcriptEn.trim();
          final orig = v.transcript.trim();
          if (orig.isNotEmpty) _desc.text = orig; // artisan's own language
          _descLocal = en.isNotEmpty && en.toLowerCase() != orig.toLowerCase();
          _descEn = _descLocal ? en : '';
        });
      } catch (e) {
        _toast("Couldn't transcribe: $e");
      } finally {
        if (mounted) setState(() => _transcribing = false);
      }
      return;
    }
    if (!voiceIsLive) {
      _toast('Voice needs a Gemini or Bhashini key in the build');
      return;
    }
    if (!await _recorder.hasPermission()) {
      _toast('Microphone permission denied');
      return;
    }
    final path =
        '${Directory.systemTemp.path}/desc_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
          encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _recording = true;
      _voice = null;
    });
  }

  // ---------------- Analyse & publish ----------------

  void _recalcPrice() {
    final raw = double.tryParse(_rawCost.text.trim()) ?? 0;
    final hrs = double.tryParse(_hours.text.trim()) ?? 0;
    final r = _result;
    double suggested;
    if (raw > 0 || hrs > 0) {
      suggested = (raw + hrs * _wage + raw * _overheadRate) * (1 + _margin);
    } else if (r?.priceMin != null && r?.priceMax != null) {
      suggested = (r!.priceMin! + r.priceMax!) / 2;
    } else {
      suggested = double.tryParse(_price.text.trim()) ?? 1000;
    }
    final rounded = (suggested / 50).round() * 50;
    setState(() => _price.text = rounded.toString());
  }

  Future<void> _analyze() async {
    final primary = _primary;
    if (primary == null) return;
    setState(() => _busy = true);
    // English context for the model (translation if the artisan spoke a
    // regional language, otherwise the typed/spoken text as-is).
    final ctx = _descLocal && _descEn.isNotEmpty ? _descEn : _desc.text.trim();
    final r = await generateCatalogFromPhoto(
      primary.bytes,
      mediaType: primary.mediaType,
      imagePath: primary.path,
      craftHint: ctx.isEmpty ? null : ctx,
      location: 'Rekha Devi · Bhuj, Gujarat',
      moreImages: _photos.skip(1).map((e) => e.bytes).toList(),
    );
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
      _name.text = r.productName;
      _materials.text = r.materials.join(', ');
      if (_rate.text.trim().isEmpty) _rate.text = _wagePerHour.round().toString();
      _tags.text = r.tags.map((t) => '#${t.replaceAll(' ', '')}').join(' ');
      if (_descLocal) {
        // Keep the artisan's own-language description; use the AI's English
        // copy for buyers.
        if (r.description.trim().isNotEmpty) _descEn = r.description.trim();
      } else if (_desc.text.trim().isEmpty) {
        _desc.text = r.description; // English
      }
    });
    _recalcPrice();
  }

  Future<void> _publish() async {
    final r = _result;
    if (r == null) return;
    final price = int.tryParse(_price.text.trim()) ?? (r.priceMin ?? 1000);
    final mats = _materials.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final localText = _desc.text.trim();
    // Buyers always see English.
    final english = _descLocal
        ? (_descEn.isNotEmpty ? _descEn : (r.description))
        : (localText.isEmpty ? r.description : localText);
    final product = Product(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim().isEmpty ? r.productName : _name.text.trim(),
      nameLocal: r.nameLocal,
      price: price,
      category: r.category,
      sub: r.craftType,
      artisan: 'Rekha Devi',
      location: 'Bhuj, Gujarat',
      description: english,
      descriptionLocal: _descLocal ? localText : '',
      cultural: r.culturalContext,
      materials: mats.isEmpty ? r.materials : mats,
      c1: AppColors.green,
      c2: AppColors.terracotta,
      imageBytes: _primary?.bytes,
      segments: [...r.b2cSegments, ...r.b2bSegments],
    );
    userProducts.add(product);
    saveUserProduct(product);
    _toast('Published — see it in Buyer ▸ Featured Products');
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final full = _photos.length >= _maxPhotos;
    return Scaffold(
      appBar: AppBar(
          title:
              Text('AI Camera', style: serif(size: 17, color: AppColors.green))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _providerBadge(),
        const SizedBox(height: 12),
        _photoStrip(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: (_busy || full) ? null : _addFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'))),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: (_busy || full) ? null : _addFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'))),
        ]),
        if (_primary != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_busy || _cutoutBusy || (_primary?.cutout ?? false))
                  ? null
                  : _removeBackground,
              icon: _cutoutBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon((_primary?.cutout ?? false)
                      ? Icons.check
                      : Icons.auto_fix_high, size: 18),
              label: Text(_cutoutBusy
                  ? 'Removing background…'
                  : (_primary?.cutout ?? false)
                      ? 'Background removed'
                      : 'Remove background — main photo'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _field('Describe your craft (in your language — or use voice)', _desc,
            lines: 3),
        if (_descLocal && _descEn.isNotEmpty) _englishPreview(),
        const SizedBox(height: 10),
        _voiceButton(),
        if (_voice != null && _voice!.transcript.trim().isNotEmpty)
          _voiceCard(_voice!),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_primary == null || _busy) ? null : _analyze,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_busy ? 'Analysing…' : 'Analyse with AI'),
          ),
        ),
        if (r != null) ...[
          const SizedBox(height: 20),
          _resultCard(r),
        ],
      ]),
    );
  }

  Widget _photoStrip() {
    if (_photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.muted),
            SizedBox(height: 8),
            Text('Add 1–3 photos of your craft',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Photos (${_photos.length}/$_maxPhotos)',
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      const SizedBox(height: 6),
      SizedBox(
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _thumb(i),
        ),
      ),
    ]);
  }

  Widget _thumb(int i) {
    final blurryMain = i == 0 && _isBlurry;
    return SizedBox(
      width: 116,
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_photos[i].bytes, fit: BoxFit.cover),
          ),
        ),
        if (i == 0)
          Positioned(
            left: 6,
            top: 6,
            child: _tag('Main', AppColors.green),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(i),
            child: Container(
              decoration: const BoxDecoration(
                  color: Color(0xCC000000), shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
        if (blurryMain)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xE6B55A34),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
              child: const Text('blurry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      );

  Widget _englishPreview() => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.translate, size: 14, color: AppColors.greenSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Buyers will see (English): $_descEn',
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic,
                    height: 1.3)),
          ),
        ]),
      );

  Widget _voiceButton() {
    final recording = _recording;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _toggleVoice,
        style: OutlinedButton.styleFrom(
          foregroundColor: recording ? AppColors.kala : AppColors.green,
          side: BorderSide(color: recording ? AppColors.kala : AppColors.line),
        ),
        icon: _transcribing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(recording ? Icons.stop_circle : Icons.mic, size: 18),
        label: Text(_transcribing
            ? 'Transcribing…'
            : recording
                ? 'Stop & transcribe'
                : 'Describe by voice ($voiceEngineLabel)'),
      ),
    );
  }

  Widget _voiceCard(VoiceResult v) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.creamDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.graphic_eq, size: 15, color: AppColors.green),
            const SizedBox(width: 6),
            Text('Heard (${v.language})',
                style: serif(size: 13, color: AppColors.green)),
          ]),
          const SizedBox(height: 4),
          Text(v.transcript, style: const TextStyle(fontSize: 13, height: 1.3)),
        ]),
      );

  Widget _providerBadge() {
    final live = aiIsLive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: live ? AppColors.creamDeep : const Color(0xFFF3EFE6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Icon(live ? Icons.bolt : Icons.wifi_off,
            size: 16, color: live ? AppColors.greenSoft : AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(live ? 'Live AI: $aiModelLabel' : 'On-device AI (offline)',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ),
      ]),
    );
  }

  Widget _resultCard(CatalogResult r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('AI draft listing', style: serif(size: 18, color: AppColors.green)),
        const Spacer(),
        _confidencePill(r.confidence),
      ]),
      const SizedBox(height: 4),
      Text('${r.craftType} · ${r.category}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 2),
      Text('Analysed by ${r.provider}',
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.greenSoft,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (r.fieldsRequiringConfirmation.isNotEmpty) _confirmBanner(r),
      Panel(child: _field('Product name', _name)),
      const SizedBox(height: 14),
      Text('A few questions to price it fairly',
          style: serif(size: 15, color: AppColors.green)),
      const SizedBox(height: 8),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field('Which material(s) is it made from?', _materials),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field('Raw material cost (₹)', _rawCost,
                    number: true, onChanged: (_) => _recalcPrice())),
            const SizedBox(width: 10),
            Expanded(
                child: _field('Hours to make', _hours,
                    number: true, onChanged: (_) => _recalcPrice())),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field('Rate per hour (₹)', _rate,
                    number: true, onChanged: (_) => _recalcPrice())),
            const SizedBox(width: 10),
            Expanded(child: _field('Inventory left', _inventory, number: true)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.creamDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.sell_outlined, size: 16, color: AppColors.green),
                const SizedBox(width: 6),
                Text('Suggested price',
                    style: serif(size: 14, color: AppColors.green)),
                const Spacer(),
                TextButton(
                    onPressed: _recalcPrice,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Recalculate',
                        style: TextStyle(fontSize: 11))),
              ]),
              const SizedBox(height: 8),
              _field('Price (₹) — edit if needed', _price, number: true),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (r.nameLocal.isNotEmpty) _kv('Local name', r.nameLocal),
      _chips('Materials', r.materials),
      _chips('Colours', r.colors),
      _chips('Recommended markets', r.recommendedMarkets),
      _chips('B2C segments', r.b2cSegments),
      _chips('B2B segments', r.b2bSegments),
      _chips('Tags', r.tags),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _field('Add your hashtags (e.g. #handmade #gujarat)', _tags),
      ),
      if (r.culturalContext.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Cultural context', style: serif(size: 14, color: AppColors.green)),
        const SizedBox(height: 4),
        Text(r.culturalContext,
            style: const TextStyle(fontSize: 12.5, height: 1.35)),
      ],
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _publish,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.publish),
          label: const Text('Publish to catalogue'),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _confirmBanner(CatalogResult r) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF1E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33B55A34)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.terracotta),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'Please double-check: ${r.fieldsRequiringConfirmation.join(', ')}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.terracotta, height: 1.3)),
          ),
        ]),
      );

  Widget _confidencePill(double c) {
    final pct = (c * 100).round();
    final good = c >= 0.75;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFE7F0EA) : const Color(0xFFFBF1E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$pct% confident',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: good ? AppColors.greenSoft : AppColors.terracotta)),
    );
  }

  Widget _field(String label, TextEditingController c,
          {int lines = 1, bool number = false, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
              children: [
                TextSpan(
                    text: '$k: ',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: v),
              ]),
        ),
      );

  Widget _chips(String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: serif(size: 14, color: AppColors.green)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final it in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(it, style: const TextStyle(fontSize: 11.5)),
            ),
        ]),
      ]),
    );
  }
}
