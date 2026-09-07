import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import '../widgets.dart';
import '../services/ai_camera.dart';

/// AI camera cataloging: capture or pick a product photo, send it to Claude
/// vision (or the offline mock), and get an auto-filled, editable listing.
class AiCameraScreen extends StatefulWidget {
  const AiCameraScreen({super.key});
  @override
  State<AiCameraScreen> createState() => _AiCameraScreenState();
}

class _AiCameraScreenState extends State<AiCameraScreen> {
  final _picker = ImagePicker();
  final _hint = TextEditingController();
  final _name = TextEditingController();
  final _priceMin = TextEditingController();
  final _priceMax = TextEditingController();
  final _desc = TextEditingController();

  Uint8List? _bytes;
  String _mediaType = 'image/jpeg';
  CatalogResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _hint.dispose();
    _name.dispose();
    _priceMin.dispose();
    _priceMax.dispose();
    _desc.dispose();
    super.dispose();
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
        _mediaType = mt;
        _result = null;
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
      craftHint: _hint.text.trim().isEmpty ? null : _hint.text.trim(),
      location: 'Rekha Devi · Bhuj, Gujarat',
    );
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
      _name.text = r.productName;
      _priceMin.text = (r.priceMin ?? '').toString();
      _priceMax.text = (r.priceMax ?? '').toString();
      _desc.text = r.description;
    });
  }

  void _publish() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Listing published to your catalogue (demo)')));
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
            : Image.memory(_bytes!, fit: BoxFit.cover),
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
      const SizedBox(height: 12),
      if (r.fieldsRequiringConfirmation.isNotEmpty) _confirmBanner(r),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field('Product name', _name),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field('Price min (₹)', _priceMin, number: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Price max (₹)', _priceMax, number: true)),
          ]),
          const SizedBox(height: 12),
          _field('Description', _desc, lines: 4),
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
          {int lines = 1, bool number = false}) =>
      TextField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
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
