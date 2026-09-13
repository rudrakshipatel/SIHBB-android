import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'buyer.dart';
import 'product_detail.dart';
import 'pages.dart';
import 'ai_camera.dart';
import 'language.dart';
import '../services/identity.dart';
import '../services/i18n.dart';

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
    return Localized((context) => Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.creamDeep,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: t('Products')),
          NavigationDestination(icon: const Icon(Icons.add_circle_outline), selectedIcon: const Icon(Icons.add_circle), label: t('Add')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t('Profile')),
        ],
      ),
    ));
  }
}

/// Top-right "Buyer" button to switch the whole app to the buyer experience.
Widget _buyerSwitchButton(BuildContext context) => TextButton(
      onPressed: () => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const BuyerShell())),
      child: Text(t('Buyer'),
          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
    );

class _MyProducts extends StatelessWidget {
  const _MyProducts();
  @override
  Widget build(BuildContext context) {
    final mine = products.take(6).toList();
    return Localized((context) => Column(children: [
      AppBar(title: Text(t('My Products'), style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false, actions: [_buyerSwitchButton(context)]),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72), itemCount: mine.length, itemBuilder: (_, i) => ProductCard(mine[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(mine[i])))))),
    ]));
  }
}

class _Inquiries extends StatelessWidget {
  const _Inquiries();
  @override
  Widget build(BuildContext context) {
    return Localized((context) => Scaffold(
      appBar: AppBar(title: Text(t('Inquiries'), style: serif(size: 17, color: AppColors.green))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final i in inquiries) Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: i.type == 'B2B' ? const Color(0x1A22402E) : AppColors.creamDeep, borderRadius: BorderRadius.circular(6)), child: Text(i.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: i.type == 'B2B' ? AppColors.green : AppColors.terracotta))),
            const Spacer(),
            Text(t(i.when), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text('${t(i.buyer)} — ${t(i.title)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(t(i.meta), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _snack(context, 'Reply sent'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green)), child: Text(t('Reply')))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () => _snack(context, 'Quote sent'), style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta), child: Text(t('Send Quote')))),
          ]),
        ]))),
      ]),
    ));
  }

  void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t(m))));
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
    return Localized((context) => Column(children: [
      AppBar(title: Text(t('Add Product'), style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false, actions: [_buyerSwitchButton(context)]),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('Turn your craft into a listing in under 90 seconds.'), style: serif(size: 18, color: AppColors.green)),
        const SizedBox(height: 18),
        for (var i = 0; i < steps.length; i++) Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(color: AppColors.creamDeep, shape: BoxShape.circle),
            child: Icon(steps[i].$1, color: AppColors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ${t(steps[i].$2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            const SizedBox(height: 3),
            Text(t(steps[i].$3), style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.3)),
          ])),
        ]))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiCameraScreen())), style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta, padding: const EdgeInsets.symmetric(vertical: 16)), icon: const Icon(Icons.camera_alt_outlined), label: Text(t('Start with a photo')))),
      ])),
    ]));
  }
}

class _SellerProfile extends StatefulWidget {
  const _SellerProfile();
  @override
  State<_SellerProfile> createState() => _SellerProfileState();
}

class _SellerProfileState extends State<_SellerProfile> {
  Future<void> _editShop() async {
    final nameC = TextEditingController(text: identity.name);
    final locC = TextEditingController(text: identity.location);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Your shop details'), style: serif(size: 17, color: AppColors.green)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: InputDecoration(labelText: t('Your / shop name'), border: const OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          TextField(controller: locC, decoration: InputDecoration(labelText: t('Location (e.g. Bhuj, Gujarat)'), border: const OutlineInputBorder(), isDense: true)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.green), onPressed: () => Navigator.pop(ctx, true), child: Text(t('Save'))),
        ],
      ),
    );
    if (saved == true) {
      await updateSellerProfile(name: nameC.text, location: locC.text);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = identity;
    final initial = id.name.trim().isNotEmpty ? id.name.trim().substring(0, 1).toUpperCase() : 'A';
    return Localized((context) => Column(children: [
      AppBar(title: Text(t('Profile'), style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: AppColors.creamDeep, child: Text(initial, style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800, fontSize: 22))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text(id.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))), const SizedBox(width: 6), const Icon(Icons.verified, color: AppColors.greenSoft, size: 16)]),
            Text('${t('Artisan')} · ${id.location}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted), onPressed: _editShop),
        ])),
        const SizedBox(height: 12),
        _tile(context, Icons.language, t('Language'), const LanguageScreen()),
        _tile(context, Icons.chat_bubble_outline, t('Inquiries'), const _Inquiries()),
        _tile(context, Icons.qr_code_2, t('My QR code'), const QrScreen()),
        _tile(context, Icons.insights_outlined, t('Insights'), const InsightsScreen()),
        _tile(context, Icons.event_outlined, t('Exhibitions'), const ExhibitionsScreen()),
        _tile(context, Icons.payments_outlined, t('Payments'), const PaymentsScreen()),
        Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const Icon(Icons.storefront_outlined, color: AppColors.green), title: Text(t('Switch to Buyer'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: AppColors.muted), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerShell())))),
      ])),
    ]));
  }

  Widget _tile(BuildContext context, IconData icon, String label, Widget page) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(icon, color: AppColors.green), title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: AppColors.muted), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))));
}
