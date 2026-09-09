import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'buyer.dart';
import 'product_detail.dart';
import 'pages.dart';
import 'ai_camera.dart';

class SellerShell extends StatefulWidget {
  const SellerShell({super.key});
  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  int _tab = 1; // default to the Add tab
  @override
  Widget build(BuildContext context) {
    final pages = [const _MyProducts(), const _AddProduct(), const _SellerProfile()];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.creamDeep,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final done = profileTasks.where((t) => t.done).length;
    final pct = (done / profileTasks.length * 100).round();
    final mine = products.take(4).toList();
    return CustomScrollView(slivers: [
      SliverAppBar(floating: true, backgroundColor: Colors.white, titleSpacing: 16, title: const BrandLogo(size: 30),
        actions: [TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerShell())), child: const Text('Buyer', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)))]),
      SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList(delegate: SliverChildListDelegate([
        // greeting banner
        Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 150, width: double.infinity, child: Image.asset('assets/seller-hero.jpg', fit: BoxFit.cover))),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [AppColors.cream.withValues(alpha: 0.96), AppColors.cream.withValues(alpha: 0.15)], begin: Alignment.centerLeft, end: Alignment.centerRight)))),
          Positioned(left: 16, top: 20, right: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Namaste, Rekha Devi 🙏', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text('Let\'s grow your craft together.', style: serif(size: 18, color: AppColors.green)),
            const SizedBox(height: 10),
            TextButton(onPressed: () {}, style: TextButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))), child: const Text('➕ Add New Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ])),
        ]),
        const SizedBox(height: 14),
        // profile strength
        Panel(child: Row(children: [
          ProfileRing(pct),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('Profile Strength', style: serif(size: 15, color: AppColors.green)), const Spacer(), const Text('🌿')]),
            const SizedBox(height: 6),
            for (final t in profileTasks)
              Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                t.done ? const Icon(Icons.check, size: 15, color: AppColors.greenSoft) : Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: AppColors.terracotta, borderRadius: BorderRadius.circular(6)), child: const Text('Verify', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
              ])),
          ])),
        ])),
        const SizedBox(height: 14),
        // stat cards
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [
          for (final s in dashboardStats) _statCard(s),
        ]),
        const SizedBox(height: 14),
        const SectionHeader('Recent Inquiries'),
        for (final i in inquiries) _inquiryRow(i),
        const SizedBox(height: 16),
        const SectionHeader('My Products'),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72, children: [
          for (final p in mine) ProductCard(p, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(p)))),
        ]),
        const SizedBox(height: 16),
        const SectionHeader('Your Top Insights'),
        Panel(child: Column(children: [
          for (final ins in insights) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0x1A22402E), child: Icon(Icons.trending_up, size: 16, color: AppColors.green)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ins.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(ins.detail, style: const TextStyle(color: AppColors.muted, fontSize: 11))])),
            Text(ins.metric, style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800)),
          ])),
        ])),
        const SizedBox(height: 14),
        // QR banner
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)), child: Row(children: [
          const Icon(Icons.qr_code_2, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Your Public Profile is Live!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('Share your QR at exhibitions to grow your business.', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ])),
        const SizedBox(height: 24),
      ]))),
    ]);
  }

  Widget _statCard(Stat s) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 15, backgroundColor: const Color(0x1A22402E), child: Icon(s.icon, size: 15, color: AppColors.green)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(s.value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(s.label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          ])),
        ]),
        const SizedBox(height: 2),
        Text('${s.delta} vs last month', style: const TextStyle(color: AppColors.greenSoft, fontSize: 10, fontWeight: FontWeight.w600)),
        Expanded(child: Sparkline(s.spark, color: s.label.contains('Earnings') || s.label.contains('Inquiries') ? AppColors.terracotta : AppColors.greenSoft)),
      ])));

  Widget _inquiryRow(Inquiry i) => Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: i.type == 'B2B' ? const Color(0x1A22402E) : AppColors.creamDeep, borderRadius: BorderRadius.circular(6)), child: Text(i.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: i.type == 'B2B' ? AppColors.green : AppColors.terracotta))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text('${i.meta} · ${i.when}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ])),
        if (i.isNew) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(6)), child: const Text('New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
      ])));
}

/// Top-right "Buyer" button to switch the whole app to the buyer experience.
Widget _buyerSwitchButton(BuildContext context) => TextButton(
      onPressed: () => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const BuyerShell())),
      child: const Text('Buyer',
          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
    );

class _MyProducts extends StatelessWidget {
  const _MyProducts();
  @override
  Widget build(BuildContext context) {
    final mine = products.take(6).toList();
    return Column(children: [
      AppBar(title: Text('My Products', style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false, actions: [_buyerSwitchButton(context)]),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72), itemCount: mine.length, itemBuilder: (_, i) => ProductCard(mine[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(mine[i])))))),
    ]);
  }
}

class _Inquiries extends StatelessWidget {
  const _Inquiries();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inquiries', style: serif(size: 17, color: AppColors.green))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final i in inquiries) Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: i.type == 'B2B' ? const Color(0x1A22402E) : AppColors.creamDeep, borderRadius: BorderRadius.circular(6)), child: Text(i.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: i.type == 'B2B' ? AppColors.green : AppColors.terracotta))),
            const Spacer(),
            Text(i.when, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text('${i.buyer} — ${i.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(i.meta, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _snack(context, 'Reply sent'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green)), child: const Text('Reply'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () => _snack(context, 'Quote sent'), style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta), child: const Text('Send Quote'))),
          ]),
        ]))),
      ]),
    );
  }

  void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

class _AddProduct extends StatelessWidget {
  const _AddProduct();
  @override
  Widget build(BuildContext context) {
    const steps = <(IconData, String, String)>[
      (Icons.photo_camera_outlined, 'Add photos', 'Snap or upload 1–3 clear photos of your craft'),
      (Icons.mic_none, 'Describe by voice', 'Speak in your language — AI transcribes it'),
      (Icons.auto_awesome, 'AI builds the catalog', 'Title, description, tags & fair price, auto-generated'),
      (Icons.rocket_launch_outlined, 'Publish', 'Your product goes live to buyers across India'),
    ];
    return Column(children: [
      AppBar(title: Text('Add Product', style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false, actions: [_buyerSwitchButton(context)]),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Turn your craft into a listing in under 90 seconds.', style: serif(size: 18, color: AppColors.green)),
        const SizedBox(height: 18),
        for (var i = 0; i < steps.length; i++) Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(color: AppColors.creamDeep, shape: BoxShape.circle),
            child: Icon(steps[i].$1, color: AppColors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ${steps[i].$2}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            const SizedBox(height: 3),
            Text(steps[i].$3, style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.3)),
          ])),
        ]))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiCameraScreen())), style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta, padding: const EdgeInsets.symmetric(vertical: 16)), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Start with a photo'))),
      ])),
    ]);
  }
}

class _SellerProfile extends StatelessWidget {
  const _SellerProfile();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppBar(title: Text('Profile', style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(child: Row(children: [
          const CircleAvatar(radius: 28, backgroundColor: AppColors.creamDeep, child: Text('R', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800, fontSize: 22))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Text('Rekha Devi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(width: 6), const Icon(Icons.verified, color: AppColors.greenSoft, size: 16)]),
            const Text('Terracotta Artisan · Gorakhpur, UP', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
        ])),
        const SizedBox(height: 12),
        _tile(context, Icons.chat_bubble_outline, 'Inquiries', const _Inquiries()),
        _tile(context, Icons.qr_code_2, 'My QR code', const QrScreen()),
        _tile(context, Icons.insights_outlined, 'Insights', const InsightsScreen()),
        _tile(context, Icons.event_outlined, 'Exhibitions', const ExhibitionsScreen()),
        _tile(context, Icons.payments_outlined, 'Payments', const PaymentsScreen()),
        Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const Icon(Icons.storefront_outlined, color: AppColors.green), title: const Text('Switch to Buyer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: AppColors.muted), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerShell())))),
      ])),
    ]);
  }

  Widget _tile(BuildContext context, IconData icon, String label, Widget page) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(icon, color: AppColors.green), title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: AppColors.muted), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))));
}
