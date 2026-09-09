import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import '../services/ai_camera.dart';
import '../services/store.dart';

/// AI camera cataloging: capture or pick a product photo, send it to Claude
/// vision (or the offline mock), and get an auto-filled, editable listing.
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

  final _picker = ImagePicker();
  final _hint = TextEditingController();
  final _name = TextEditingController();
  final _materials = TextEditingController();
  final _rawCost = TextEditingController();
  final _hours = TextEditingController();
  final _rate = TextEditingController();
  final _inventory = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _tags = TextEditingController();

  // Photo-quality: variance-of-Laplacian (0-255 gray). Higher = sharper.
  static const double _blurWarn = 100; // below this we warn the artisan

  Uint8List? _bytes;
  String? _path;
  String _mediaType = 'image/jpeg';
  double? _sharpness; // variance of Laplacian for the current photo
  bool _cutout = false; // background already removed for the current photo
  bool _cutoutBusy = false;
  CatalogResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _hint.dispose();
    _name.dispose();
    _materials.dispose();
    _rawCost.dispose();
    _hours.dispose();
    _rate.dispose();
    _inventory.dispose();
    _price.dispose();
    _desc.dispose();
    _tags.dispose();
    super.dispose();
  }

  /// Artisan-entered hourly rate, defaulting to the standard wage when blank.
  double get _wage => double.tryParse(_rate.text.trim()) ?? _wagePerHour;

  /// On-device blur score = variance of the Laplacian over a downscaled
  /// grayscale copy. Runs offline; higher means sharper.
  double _computeSharpness(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return _blurWarn; // unknown -> don't warn
    final g = img.grayscale(img.copyResize(decoded, width: 320));
    final w = g.width, h = g.height;
    double lum(int x, int y) => g.getPixel(x, y).r.toDouble();
    double sum = 0, sumSq = 0;
    int n = 0;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final lap =
            4 * lum(x, y) - lum(x - 1, y) - lum(x + 1, y) - lum(x, y - 1) - lum(x, y + 1);
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n == 0) return _blurWarn;
    final mean = sum / n;
    return sumSq / n - mean * mean; // variance of Laplacian
  }

  bool get _isBlurry => _sharpness != null && _sharpness! < _blurWarn;

  /// On-device background removal (ML Kit Subject Segmentation — no key, no
  /// network after the model downloads). Composites the subject onto white and
  /// makes that the product photo.
  Future<void> _removeBackground() async {
    final path = _path;
    if (path == null || _cutoutBusy) return;
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
          await segmenter.processImage(InputImage.fromFilePath(path));
      final fg = result.foregroundBitmap;
      final fgImg = fg == null ? null : img.decodeImage(fg);
      if (fgImg == null) throw Exception('no subject detected');
      // Flatten the transparent cut-out onto a white studio background.
      final canvas = img.Image(width: fgImg.width, height: fgImg.height);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, fgImg);
      final out = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
      final tmp = File(
          '${Directory.systemTemp.path}/cutout_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tmp.writeAsBytes(out);
      if (!mounted) return;
      setState(() {
        _bytes = out;
        _path = tmp.path;
        _mediaType = 'image/jpeg';
        _cutout = true;
        _sharpness = _computeSharpness(out);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't remove background: $e")));
    } finally {
      await segmenter.close();
      if (mounted) setState(() => _cutoutBusy = false);
    }
  }

  /// Suggests one fixed price from the artisan's costs (editable afterwards).
  /// Falls back to the AI category ballpark until costs are entered.
  void _recalcPrice() {
    final raw = double.tryParse(_rawCost.text.trim()) ?? 0;
    final hrs = double.tryParse(_hours.text.trim()) ?? 0;
    final r = _result;
    double suggested;
    if (raw > 0 || hrs > 0) {
      final overhead = raw * _overheadRate; // O = k * C_raw
      suggested = (raw + hrs * _wage + overhead) * (1 + _margin);
    } else if (r?.priceMin != null && r?.priceMax != null) {
      suggested = (r!.priceMin! + r.priceMax!) / 2;
    } else {
      suggested = double.tryParse(_price.text.trim()) ?? 1000;
    }
    final rounded = (suggested / 50).round() * 50; // nearest ₹50
    setState(() => _price.text = rounded.toString());
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
          source: source, maxWidth: 1280, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final path = x.path.toLowerCase();
      final mt = path.endsWith('.png')
          ? 'image/png'
          : path.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      setState(() {
        _bytes = bytes;
        _path = x.path;
        _mediaType = mt;
        _result = null;
        _cutout = false;
        _sharpness = _computeSharpness(bytes);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the camera/gallery: $e')));
    }
  }

  Future<void> _analyze() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    final r = await generateCatalogFromPhoto(
      bytes,
      mediaType: _mediaType,
      imagePath: _path,
      craftHint: _hint.text.trim().isEmpty ? null : _hint.text.trim(),
      location: 'Rekha Devi · Bhuj, Gujarat',
    );
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
      _name.text = r.productName;
      _desc.text = r.description;
      _materials.text = r.materials.join(', ');
      if (_rate.text.trim().isEmpty) _rate.text = _wagePerHour.round().toString();
      _tags.text = r.tags.map((t) => '#${t.replaceAll(' ', '')}').join(' ');
    });
    _recalcPrice(); // seed the fixed price from the AI ballpark
  }

  void _publish() {
    final r = _result;
    if (r == null) return;
    final price = int.tryParse(_price.text.trim()) ?? (r.priceMin ?? 1000);
    final mats = _materials.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final product = Product(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim().isEmpty ? r.productName : _name.text.trim(),
      nameLocal: r.nameLocal,
      price: price,
      category: r.category,
      sub: r.craftType,
      artisan: 'Rekha Devi',
      location: 'Bhuj, Gujarat',
      description: _desc.text.trim().isEmpty ? r.description : _desc.text.trim(),
      cultural: r.culturalContext,
      materials: mats.isEmpty ? r.materials : mats,
      c1: AppColors.green,
      c2: AppColors.terracotta,
      imageBytes: _bytes,
      segments: [...r.b2cSegments, ...r.b2bSegments],
    );
    userProducts.add(product);
    saveUserProduct(product); // persist offline (SQLite)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Published — see it in Buyer ▸ Featured Products')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(
          title: Text('AI Camera', style: serif(size: 17, color: AppColors.green))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _providerBadge(),
        const SizedBox(height: 12),
        _photoArea(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'))),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'))),
        ]),
        if (_bytes != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  (_busy || _cutoutBusy || _cutout) ? null : _removeBackground,
              icon: _cutoutBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_cutout ? Icons.check : Icons.auto_fix_high,
                      size: 18),
              label: Text(_cutoutBusy
                  ? 'Removing background…'
                  : _cutout
                      ? 'Background removed'
                      : 'Remove background (on-device)'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _hint,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            labelText: 'Craft hint (optional)',
            hintText: 'e.g. terracotta bowl, saree, brass birds',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_bytes == null || _busy) ? null : _analyze,
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
            label: Text(_busy ? 'Analysing photo…' : 'Analyse with AI'),
          ),
        ),
        if (r != null) ...[
          const SizedBox(height: 20),
          _resultCard(r),
        ],
      ]),
    );
  }

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
          child: Text(
            live
                ? 'Live AI: $aiModelLabel'
                : 'Demo mode — offline mock (build with an ANTHROPIC_API_KEY for live Claude vision)',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
      ]),
    );
  }

  Widget _photoArea() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: _bytes == null
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_a_photo_outlined,
                    size: 40, color: AppColors.muted),
                SizedBox(height: 8),
                Text('Snap or choose a photo of your craft',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ]))
            : Stack(fit: StackFit.expand, children: [
                Image.memory(_bytes!, fit: BoxFit.cover),
                if (_isBlurry)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: const Color(0xE6B55A34),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.blur_on, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text('This photo looks blurry — a sharper one sells better',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ),
              ]),
      ),
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
              fontSize: 11, color: AppColors.greenSoft, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (r.fieldsRequiringConfirmation.isNotEmpty) _confirmBanner(r),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field('Product name', _name),
          const SizedBox(height: 12),
          _field('Description', _desc, lines: 3),
        ]),
      ),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.sell_outlined, size: 16, color: AppColors.green),
                const SizedBox(width: 6),
                Text('Suggested price', style: serif(size: 14, color: AppColors.green)),
                const Spacer(),
                TextButton(
                    onPressed: _recalcPrice,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Recalculate', style: TextStyle(fontSize: 11))),
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
        Text('Cultural context',
            style: serif(size: 14, color: AppColors.green)),
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
                  fontSize: 12, color: AppColors.terracotta, height: 1.3),
            ),
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
          text: TextSpan(style: const TextStyle(fontSize: 12.5, color: AppColors.ink), children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
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
