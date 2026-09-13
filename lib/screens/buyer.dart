import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'product_detail.dart';
import 'seller.dart';
import 'pages.dart';
import 'language.dart';
import '../services/supabase.dart';
import '../services/i18n.dart';

class BuyerShell extends StatefulWidget {
  final String? initialCategory;
  const BuyerShell({super.key, this.initialCategory});
  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Opened with a category (e.g. from the landing page) → jump to that list.
    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProductsScreen(initialCategory: widget.initialCategory)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const BuyerHome(), const CartScreen(), const _BuyerProfile()];
    return Localized((context) => Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.creamDeep,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: t('Home')),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: cart.isNotEmpty,
                label: Text('${cart.length}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_cart),
              label: t('Cart')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: t('Account')),
        ],
      ),
    ));
  }
}

class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});
  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await refreshRemoteProducts();
    if (mounted) setState(() {});
  }

  void _open(BuildContext c, Product p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => ProductDetail(p)));

  void _browse(BuildContext c, {String? category}) => Navigator.push(c,
      MaterialPageRoute(builder: (_) => ProductsScreen(initialCategory: category)));

  @override
  Widget build(BuildContext context) {
    final featured = allProducts.take(6).toList();
    return Localized((context) => RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
      SliverAppBar(
        floating: true,
        backgroundColor: Colors.white,
        titleSpacing: 16,
        title: const BrandLogo(size: 32),
        actions: [
          TextButton(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SellerShell())),
              child: Text(t('Seller'),
                  style: const TextStyle(
                      color: AppColors.terracotta, fontWeight: FontWeight.w700)))
        ],
      ),
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeader(t('Shop by Category')),
                SizedBox(
                    height: 108,
                    child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => CategoryTile(categories[i],
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        SubcategoryScreen(categories[i])))))),
                const SizedBox(height: 22),
                SectionHeader(t('Featured Products'),
                    action: t('View all'), onAction: () => _browse(context)),
              ]))),
      SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72),
            delegate: SliverChildBuilderDelegate(
                (_, i) =>
                    ProductCard(featured[i], onTap: () => _open(context, featured[i])),
                childCount: featured.length),
          )),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ])));
  }
}

/// Full product list, reached by pushing (not a bottom tab). Manages its own
/// category filter.
class ProductsScreen extends StatefulWidget {
  final String? initialCategory;
  const ProductsScreen({super.key, this.initialCategory});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _load();
  }

  Future<void> _load() async {
    await refreshRemoteProducts();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _category == null
        ? allProducts
        : allProducts.where((p) => p.category == _category).toList();
    return Localized((context) => Scaffold(
      appBar: AppBar(
          title: Text(_category ?? t('All Products'),
              style: serif(size: 17, color: AppColors.green))),
      body: Column(children: [
        SizedBox(
            height: 44,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip(t('All'), _category == null, () => setState(() => _category = null)),
                  for (final c in categories)
                    _chip(c.name.split(',').first, _category == c.name,
                        () => setState(() => _category = c.name)),
                ])),
        Expanded(
            child: RefreshIndicator(
                onRefresh: _load,
                child: items.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                        Padding(
                            padding: const EdgeInsets.only(top: 100),
                            child: Center(
                                child: Text(t('No products in this category yet.'),
                                    style: const TextStyle(color: AppColors.muted))))
                      ])
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.72),
                        itemCount: items.length,
                        itemBuilder: (_, i) => ProductCard(items[i],
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ProductDetail(items[i])))),
                      ))),
      ]),
    ));
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(fontSize: 12, color: active ? Colors.white : AppColors.ink)),
          selected: active,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.green,
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: active ? AppColors.green : AppColors.line)),
        ),
      );
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final total = cart.fold<int>(0, (s, p) => s + p.price);
    return Localized((context) => Column(children: [
      AppBar(
          title: Text(t('Cart'), style: serif(size: 17, color: AppColors.green)),
          automaticallyImplyLeading: false),
      Expanded(
        child: cart.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_cart_outlined, size: 44, color: AppColors.muted),
                const SizedBox(height: 10),
                Text(t('Your cart is empty'),
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(t('Add products from the catalogue'),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cart.length,
                itemBuilder: (_, i) {
                  final p = cart[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        SizedBox(
                            width: 64,
                            height: 64,
                            child: ProductThumb(p, radius: 10)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(p.artisan,
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(p.priceLabel,
                                  style: const TextStyle(
                                      color: AppColors.terracotta,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ])),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.muted),
                          onPressed: () => setState(() => cart.removeAt(i)),
                        ),
                      ]),
                    ),
                  );
                }),
      ),
      if (cart.isNotEmpty)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Total (approx.)'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              Text(rupee(total),
                  style: serif(size: 20, color: AppColors.green)),
            ]),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              onPressed: () {
                final n = cart.length;
                setState(() => cart.clear());
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Inquiry sent for $n item(s)')));
              },
              child: Text(t('Send inquiry')),
            ),
          ]),
        ),
    ]));
  }
}

class _BuyerProfile extends StatelessWidget {
  const _BuyerProfile();
  @override
  Widget build(BuildContext context) {
    return Localized((context) => Column(children: [
      AppBar(
          title: Text(t('Account'), style: serif(size: 17, color: AppColors.green)),
          automaticallyImplyLeading: false),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        const Panel(
            child: Row(children: [
          CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.creamDeep,
              child: Text('A',
                  style: TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w800,
                      fontSize: 20))),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Arjun Mehta', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Business buyer · Mumbai',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ])),
        const SizedBox(height: 12),
        _nav(context, Icons.language, t('Language'), const LanguageScreen()),
        _nav(context, Icons.favorite_border, t('Saved items'), const SavedScreen()),
        _nav(context, Icons.receipt_long_outlined, t('My inquiries'),
            const MyInquiriesScreen()),
        _nav(context, Icons.help_outline, t('Help & Support'), const HelpScreen()),
        _action(context, Icons.storefront_outlined, t('Switch to Seller'),
            () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const SellerShell()))),
      ])),
    ]));
  }

  Widget _nav(BuildContext context, IconData icon, String label, Widget page) =>
      _action(context, icon, label,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)));

  Widget _action(
          BuildContext context, IconData icon, String label, VoidCallback onTap) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
            leading: Icon(icon, color: AppColors.green),
            title: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: onTap),
      );
}
