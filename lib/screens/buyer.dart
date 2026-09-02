import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'product_detail.dart';
import 'seller.dart';

class BuyerShell extends StatefulWidget {
  final String? initialCategory;
  const BuyerShell({super.key, this.initialCategory});
  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  late int _tab = widget.initialCategory != null ? 1 : 0;
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BuyerHome(onExplore: (cat) => setState(() { _category = cat; _tab = 1; })),
      ProductsScreen(category: _category, onCategory: (c) => setState(() => _category = c)),
      const _BuyerProfile(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.creamDeep,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

class BuyerHome extends StatelessWidget {
  final void Function(String? category) onExplore;
  const BuyerHome({super.key, required this.onExplore});
  @override
  Widget build(BuildContext context) {
    final featured = products.take(6).toList();
    return CustomScrollView(slivers: [
      SliverAppBar(
        floating: true, backgroundColor: Colors.white, titleSpacing: 16,
        title: const BrandLogo(size: 32),
        actions: [TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SellerShell())), child: const Text('Seller', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w700)))],
      ),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // hero
        Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 170, width: double.infinity, child: Image.asset('assets/buyer-hero.jpg', fit: BoxFit.cover))),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [AppColors.cream.withValues(alpha: 0.95), AppColors.cream.withValues(alpha: 0.1)], begin: Alignment.centerLeft, end: Alignment.centerRight)))),
          Positioned(left: 18, top: 30, right: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Timeless Crafts.\nMeaningful Connections.', style: serif(size: 20, color: AppColors.green)),
            const SizedBox(height: 10),
            TextButton(onPressed: () => onExplore(null), style: TextButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))), child: const Text('Explore Products →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          ])),
        ]),
        const SizedBox(height: 18),
        const SectionHeader('Shop by Category'),
        SizedBox(height: 108, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: categories.length, separatorBuilder: (_, _) => const SizedBox(width: 8), itemBuilder: (_, i) => CategoryTile(categories[i], onTap: () => onExplore(categories[i].name)))),
        const SizedBox(height: 22),
        SectionHeader('Featured Products', action: 'View all', onAction: () => onExplore(null)),
      ]))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
        delegate: SliverChildBuilderDelegate((_, i) => ProductCard(featured[i], onTap: () => _open(context, featured[i])), childCount: featured.length),
      )),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }

  void _open(BuildContext c, Product p) => Navigator.push(c, MaterialPageRoute(builder: (_) => ProductDetail(p)));
}

class ProductsScreen extends StatelessWidget {
  final String? category;
  final void Function(String?) onCategory;
  const ProductsScreen({super.key, this.category, required this.onCategory});
  @override
  Widget build(BuildContext context) {
    final items = category == null ? products : products.where((p) => p.category == category).toList();
    return Column(children: [
      AppBar(title: Text(category ?? 'All Products', style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false),
      SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        _chip(context, 'All', category == null, () => onCategory(null)),
        for (final c in categories) _chip(context, c.name.split(',').first, category == c.name, () => onCategory(c.name)),
      ])),
      Expanded(child: items.isEmpty
          ? const Center(child: Text('No products in this category yet.', style: TextStyle(color: AppColors.muted)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: items.length,
              itemBuilder: (_, i) => ProductCard(items[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(items[i])))),
            )),
    ]);
  }

  Widget _chip(BuildContext c, String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : AppColors.ink)),
          selected: active,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.green,
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: active ? AppColors.green : AppColors.line)),
        ),
      );
}

class _BuyerProfile extends StatelessWidget {
  const _BuyerProfile();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppBar(title: Text('Account', style: serif(size: 17, color: AppColors.green)), automaticallyImplyLeading: false),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Panel(child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.creamDeep, child: Text('A', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800, fontSize: 20))),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Arjun Mehta', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Business buyer · Mumbai', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ])),
        const SizedBox(height: 12),
        _tile(Icons.storefront_outlined, 'Switch to Seller', () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SellerShell()))),
        _tile(Icons.home_outlined, 'Back to Landing', () => Navigator.popUntil(context, (r) => r.isFirst)),
        _tile(Icons.favorite_border, 'Saved items', null),
        _tile(Icons.receipt_long_outlined, 'My inquiries', null),
        _tile(Icons.help_outline, 'Help & Support', null),
      ])),
    ]);
  }

  Widget _tile(IconData icon, String label, VoidCallback? onTap) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(leading: Icon(icon, color: AppColors.green), title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: AppColors.muted), onTap: onTap),
      );
}
