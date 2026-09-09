import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'product_detail.dart';

AppBar _bar(String title) => AppBar(title: Text(title, style: serif(size: 17, color: AppColors.green)));

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

// ---------------- Subcategories (main category → subcategory list) ----------------
class SubcategoryScreen extends StatelessWidget {
  final Category category;
  const SubcategoryScreen(this.category, {super.key});

  Product? _sample(String sub) {
    for (final p in products) {
      if (p.category == category.name && p.sub == sub) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.name.split(',').first, style: serif(size: 17, color: AppColors.green))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // header banner using the main-category photo
        ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [
          SizedBox(height: 120, width: double.infinity, child: Image.asset(category.image, fit: BoxFit.cover)),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter)))),
          Positioned(left: 14, bottom: 12, right: 14, child: Text(category.name, style: serif(size: 18, color: Colors.white))),
        ])),
        const SizedBox(height: 16),
        Text('Browse subcategories', style: serif(size: 15, color: AppColors.green)),
        const SizedBox(height: 4),
        const Text('Pick a subcategory to see its products.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        for (final sub in category.subs)
          Card(margin: const EdgeInsets.only(bottom: 10), clipBehavior: Clip.antiAlias, child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: SizedBox(width: 52, height: 52, child: _leading(_sample(sub))),
            title: Text(sub, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(_sample(sub) == null ? 'View products' : _sample(sub)!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: category.name, sub: sub))),
          )),
      ]),
    );
  }

  Widget _leading(Product? p) {
    if (p == null) {
      return Container(decoration: BoxDecoration(color: AppColors.creamDeep, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.category_outlined, color: AppColors.green));
    }
    return ProductThumb(p, radius: 10);
  }
}

// ---------------- Category products (filtered by category + optional sub) ----------------
class CategoryProductsScreen extends StatelessWidget {
  final String category;
  final String? sub;
  const CategoryProductsScreen({super.key, required this.category, this.sub});

  @override
  Widget build(BuildContext context) {
    final items = allProducts.where((p) => p.category == category && (sub == null || p.sub == sub || p.sub.isEmpty)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(sub ?? category.split(',').first, style: serif(size: 17, color: AppColors.green))),
      body: items.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No products in this subcategory yet.\nCheck back soon.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: items.length,
              itemBuilder: (_, i) => ProductCard(items[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(items[i])))),
            ),
    );
  }
}

// ---------------- QR ----------------
class QrScreen extends StatelessWidget {
  const QrScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar('My QR Code'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('Print this and display it at your exhibition stall. Anyone who scans it opens your permanent public profile.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)), child: SizedBox(width: 200, height: 200, child: CustomPaint(painter: _QrPainter()))),
          const SizedBox(height: 12),
          const Text('hastakala.app/a/rekha-devi-terracotta', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 6),
          const Text('Total scans so far: 230', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilledButton.icon(onPressed: () => _snack(context, 'QR downloaded'), style: FilledButton.styleFrom(backgroundColor: AppColors.green), icon: const Icon(Icons.download, size: 18), label: const Text('Download')),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: () => _snack(context, 'Share sheet opened'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green)), icon: const Icon(Icons.share, size: 18), label: const Text('Share')),
          ]),
        ])),
      ]),
    );
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const n = 21;
    final cell = size.width / n;
    final p = Paint()..color = AppColors.green;
    bool finder(int i, int j) {
      bool box(int r, int c) => (i >= r && i < r + 7 && j >= c && j < c + 7) && (i == r || i == r + 6 || j == c || j == c + 6 || (i >= r + 2 && i <= r + 4 && j >= c + 2 && j <= c + 4));
      return box(0, 0) || box(0, n - 7) || box(n - 7, 0);
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final on = finder(i, j) || ((i * 7 + j * 13 + i * j) % 3 == 0 && !(i < 8 && j < 8) && !(i < 8 && j > n - 9) && !(i > n - 9 && j < 8));
        if (on) canvas.drawRect(Rect.fromLTWH(j * cell, i * cell, cell, cell), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------- Insights ----------------
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar('Insights'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7, children: [
          for (final s in dashboardStats) Panel(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s.value, style: serif(size: 20, color: AppColors.terracotta)),
            Text(s.label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            Text('${s.delta} vs last month', style: const TextStyle(color: AppColors.greenSoft, fontSize: 10, fontWeight: FontWeight.w600)),
          ])),
        ]),
        const SizedBox(height: 14),
        const SectionHeader('What this means'),
        Panel(child: Column(children: [
          for (final ins in insights) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
            const Icon(Icons.trending_up, color: AppColors.green, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('${ins.title} — ${ins.detail}', style: const TextStyle(fontSize: 13))),
            Text(ins.metric, style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800)),
          ])),
        ])),
      ]),
    );
  }
}

// ---------------- Exhibitions ----------------
class ExhibitionsScreen extends StatelessWidget {
  const ExhibitionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar('Exhibitions'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in exhibitions) Padding(padding: const EdgeInsets.only(bottom: 12), child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: e.status == 'Upcoming' ? const Color(0x1A22402E) : const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(6)), child: Text(e.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: e.status == 'Upcoming' ? AppColors.green : AppColors.muted))),
          ]),
          Text('${e.location} · ${e.dates}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            _metric('${e.scans}', 'QR Scans'),
            _metric('${e.visitors}', 'Visitors'),
            _metric('${e.inqs}', 'Inquiries'),
          ]),
        ]))),
      ]),
    );
  }

  Widget _metric(String v, String l) => Expanded(child: Column(children: [Text(v, style: serif(size: 16, color: AppColors.green)), Text(l, style: const TextStyle(fontSize: 10, color: AppColors.muted))]));
}

// ---------------- Payments ----------------
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final settled = orders.where((o) => o.status == 'Delivered').fold<int>(0, (s, o) => s + o.amount);
    final transit = orders.where((o) => o.status != 'Delivered').fold<int>(0, (s, o) => s + o.amount);
    return Scaffold(
      appBar: _bar('Payments'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: Panel(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rupee(settled), style: serif(size: 18, color: AppColors.greenSoft)), const Text('Settled earnings', style: TextStyle(color: AppColors.muted, fontSize: 11))]))),
          const SizedBox(width: 10),
          Expanded(child: Panel(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rupee(transit), style: serif(size: 18, color: AppColors.gold)), const Text('In transit', style: TextStyle(color: AppColors.muted, fontSize: 11))]))),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.creamDeep, borderRadius: BorderRadius.circular(12)), child: const Text('Payouts are settled to your bank after each order is delivered — you keep the full value of your sale, with no middleman deductions.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35))),
        const SizedBox(height: 14),
        const SectionHeader('Payout history'),
        for (final o in orders) Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
          title: Text(o.product, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text(o.buyer, style: const TextStyle(fontSize: 12)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rupee(o.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            Text(o.status == 'Delivered' ? 'Settled' : 'Pending', style: TextStyle(fontSize: 10, color: o.status == 'Delivered' ? AppColors.greenSoft : AppColors.gold, fontWeight: FontWeight.w700)),
          ]),
        )),
      ]),
    );
  }
}

// ---------------- Saved (buyer) ----------------
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final saved = products.take(4).toList();
    return Scaffold(
      appBar: _bar('Saved Items'),
      body: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72), itemCount: saved.length, itemBuilder: (_, i) => ProductCard(saved[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(saved[i]))))),
    );
  }
}

// ---------------- My inquiries (buyer) ----------------
class MyInquiriesScreen extends StatelessWidget {
  const MyInquiriesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar('My Inquiries'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final q in myInquiries) Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          leading: const CircleAvatar(backgroundColor: AppColors.creamDeep, child: Icon(Icons.receipt_long, color: AppColors.terracotta, size: 20)),
          title: Text(q.product, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text('${q.artisan} · ${q.when}', style: const TextStyle(fontSize: 12)),
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0x1A22402E), borderRadius: BorderRadius.circular(6)), child: Text(q.status, style: const TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w700))),
        )),
      ]),
    );
  }
}

// ---------------- Help ----------------
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar('Help & Support'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Column(children: [
          for (final f in faqs) ExpansionTile(
            shape: const Border(), collapsedShape: const Border(),
            title: Text(f[0], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [Align(alignment: Alignment.centerLeft, child: Text(f[1], style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)))],
          ),
        ])),
        const SizedBox(height: 12),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Still need help?', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Call the helpline 1800-HASTA-KALA or email support@hastakala.in. Support is available in Hindi and regional languages.', style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
        ])),
      ]),
    );
  }
}
