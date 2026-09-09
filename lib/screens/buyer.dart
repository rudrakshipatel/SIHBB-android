import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'product_detail.dart';
import 'seller.dart';
import 'pages.dart';

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
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.creamDeep,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: cart.isNotEmpty,
                label: Text('${cart.length}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_cart),
              label: 'Cart'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account'),
        ],
      ),
    );
  }
}

class BuyerHome extends StatelessWidget {
  const BuyerHome({super.key});

  void _open(BuildContext c, Product p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => ProductDetail(p)));

  void _browse(BuildContext c, {String? category}) => Navigator.push(c,
      MaterialPageRoute(builder: (_) => ProductsScreen(initialCategory: category)));

  @override
  Widget build(BuildContext context) {
    final featured = allProducts.take(6).toList();
    return CustomScrollView(slivers: [
      SliverAppBar(
        floating: true,
        backgroundColor: Colors.white,
        titleSpacing: 16,
        title: const BrandLogo(size: 32),
        actions: [
          TextButton(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SellerShell())),
              child: const Text('Seller',
                  style: TextStyle(
                      color: AppColors.terracotta, fontWeight: FontWeight.w700)))
        ],
      ),
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader('Shop by Category'),
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
                SectionHeader('Featured Products',
                    action: 'View all', onAction: () => _browse(context)),
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
    ]);
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
  }

  @override
  Widget build(BuildContext context) {
    final items = _category == null
        ? allProducts
        : allProducts.where((p) => p.category == _category).toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(_category ?? 'All Products',
              style: serif(size: 17, color: AppColors.green))),
      body: Column(children: [
        SizedBox(
            height: 44,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip('All', _category == null, () => setState(() => _category = null)),
                  for (final c in categories)
                    _chip(c.name.split(',').first, _category == c.name,
                        () => setState(() => _category = c.name)),
                ])),
        Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('No products in this category yet.',
                        style: TextStyle(color: AppColors.muted)))
                : GridView.builder(
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
                  )),
      ]),
    );
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
    return Column(children: [
      AppBar(
          title: Text('Cart', style: serif(size: 17, color: AppColors.green)),
          automaticallyImplyLeading: false),
      Expanded(
        child: cart.isEmpty
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_cart_outlined, size: 44, color: AppColors.muted),
                SizedBox(height: 10),
                Text('Your cart is empty',
                    style: TextStyle(color: AppColors.muted)),
                SizedBox(height: 4),
                Text('Add products from the catalogue',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
              const Text('Total (approx.)',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
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
              child: const Text('Send inquiry'),
            ),
          ]),
        ),
    ]);
  }
}

class _BuyerProfile extends StatelessWidget {
  const _BuyerProfile();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppBar(
          title: Text('Account', style: serif(size: 17, color: AppColors.green)),
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
        _nav(context, Icons.favorite_border, 'Saved items', const SavedScreen()),
        _nav(context, Icons.receipt_long_outlined, 'My inquiries',
            const MyInquiriesScreen()),
        _nav(context, Icons.help_outline, 'Help & Support', const HelpScreen()),
        _action(context, Icons.storefront_outlined, 'Switch to Seller',
            () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const SellerShell()))),
      ])),
    ]);
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
