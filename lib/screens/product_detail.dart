import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';

class ProductDetail extends StatelessWidget {
  final Product p;
  const ProductDetail(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.category.split(',').first, style: serif(size: 16, color: AppColors.green)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart_outlined),
            tooltip: 'Add to cart',
            onPressed: () {
              if (!cart.any((x) => x.id == p.id)) cart.add(p);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 4 / 3, child: ProductThumb(p, radius: 0))),
        const SizedBox(height: 16),
        Text(p.name, style: serif(size: 22, color: AppColors.green, height: 1.15)),
        const SizedBox(height: 2),
        Text(p.nameLocal, style: const TextStyle(color: AppColors.terracotta, fontSize: 14)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(child: Text(p.priceLabel, style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800, fontSize: 22))),
          if (p.priceMax != null) const Padding(padding: EdgeInsets.only(left: 6), child: Text('approx.', style: TextStyle(color: AppColors.muted, fontSize: 12))),
        ]),
        const SizedBox(height: 14),
        _label('Product Details'),
        Text(p.description, style: const TextStyle(color: AppColors.ink, height: 1.4)),
        if (p.productInfo != null) ...[
          const SizedBox(height: 14),
          _label('Product Information'),
          Text(p.productInfo!, style: const TextStyle(color: AppColors.ink, height: 1.4)),
        ],
        if (p.segments.isNotEmpty) ...[
          const SizedBox(height: 14),
          _label('Recommended Market Segments'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in p.segments)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.creamDeep, borderRadius: BorderRadius.circular(999)),
                child: Text(s, style: const TextStyle(fontSize: 11.5, color: AppColors.green, fontWeight: FontWeight.w600)),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFBF0DA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x33B45309))),
          child: Text('Cultural story: ${p.cultural}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A4B12), height: 1.35)),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in p.materials) Chip(label: Text(m, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.white, side: const BorderSide(color: AppColors.line)),
          Chip(label: Text(p.sub, style: const TextStyle(fontSize: 11)), backgroundColor: AppColors.creamDeep, side: BorderSide.none),
        ]),
        const SizedBox(height: 16),
        Panel(child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: AppColors.creamDeep, child: Text(p.artisan.substring(0, 1), style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.artisan, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(p.location, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
          const Icon(Icons.verified, color: AppColors.greenSoft, size: 18),
        ])),
        const SizedBox(height: 80),
      ]),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _inquire(context, rfq: false), style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Inquire'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: () => _inquire(context, rfq: true), style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Request Quote'))),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: serif(size: 15, color: AppColors.green)),
      );

  void _inquire(BuildContext context, {required bool rfq}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        final msg = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rfq ? 'Request a Quotation' : 'Send an Inquiry', style: serif(size: 18, color: AppColors.green)),
            const SizedBox(height: 4),
            Text(p.name, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(controller: msg, minLines: 3, maxLines: 5, decoration: InputDecoration(hintText: rfq ? 'Quantity, budget, delivery timeline…' : 'Ask about colours, sizes, availability…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📨 Inquiry sent to the artisan!'))); },
              child: Text(rfq ? 'Send Request for Quotation' : 'Send Inquiry'),
            )),
          ]),
        );
      },
    );
  }
}
