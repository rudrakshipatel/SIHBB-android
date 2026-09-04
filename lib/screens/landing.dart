import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'buyer.dart';
import 'seller.dart';
import 'pages.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openBuyer(BuildContext c, {String? category}) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => BuyerShell(initialCategory: category)));
  void _openSeller(BuildContext c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const SellerShell()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // values strip
          Container(
            width: double.infinity,
            color: AppColors.green,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Text('🪷 Empowering Artisans  ·  Preserving Traditions  ·  Connecting Markets',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          // header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const BrandLogo(size: 36),
              Row(children: [
                _headerBtn('Buyer', AppColors.green, () => _openBuyer(context)),
                const SizedBox(width: 8),
                _headerBtn('Seller', AppColors.terracotta, () => _openSeller(context)),
              ]),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
              // hero image
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(aspectRatio: 16 / 10, child: Image.asset('assets/landing-hero.webp', fit: BoxFit.cover)),
              ),
              const SizedBox(height: 20),
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Bridging Tradition.\n', style: serif(size: 30, color: AppColors.green)),
                TextSpan(text: 'Building Tomorrow.', style: serif(size: 30, color: AppColors.terracotta)),
              ])),
              const SizedBox(height: 10),
              const Text('Hastakala connects skilled artisans with the right buyers, helping traditional crafts find new markets and lasting impact.',
                  style: TextStyle(color: AppColors.muted, height: 1.4)),
              const SizedBox(height: 18),
              _roleButton('I\'m a Buyer', 'Discover & Connect', AppColors.green, Colors.white, () => _openBuyer(context)),
              const SizedBox(height: 10),
              _roleButton('I\'m an Artisan', 'Showcase & Grow', Colors.white, AppColors.green, () => _openSeller(context), outlined: true),
              const SizedBox(height: 22),
              Row(children: const [
                Expanded(child: _Trust(Icons.verified_user_outlined, 'Trusted Platform', 'Verified artisans')),
                Expanded(child: _Trust(Icons.eco_outlined, 'Authentic Crafts', 'Heritage & passion')),
                Expanded(child: _Trust(Icons.volunteer_activism_outlined, 'Real Impact', 'Empowering lives')),
              ]),
              const SizedBox(height: 26),
              Center(child: Text('Explore Authentic Handmade Crafts', style: serif(size: 18, color: AppColors.green))),
              const SizedBox(height: 4),
              const Center(child: Text('— ✦ —', style: TextStyle(color: AppColors.terracotta))),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: [for (final c in categories) CategoryTile(c, diameter: 66, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryScreen(c))))],
              ),
              const SizedBox(height: 24),
              _promoCard('For Buyers', 'Find unique handmade products and connect directly with trusted artisans.', 'Explore Products', 'assets/for-buyers.webp', AppColors.green, () => _openBuyer(context)),
              const SizedBox(height: 12),
              _promoCard('For Artisans', 'Create your digital identity, showcase your crafts and reach buyers across India and beyond.', 'Join as an Artisan', 'assets/for-artisans.png', AppColors.terracotta, () => _openSeller(context)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _headerBtn(String label, Color color, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _roleButton(String title, String sub, Color bg, Color fg, VoidCallback onTap, {bool outlined = false}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: outlined ? Border.all(color: AppColors.green.withValues(alpha: 0.3)) : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(sub, style: TextStyle(color: outlined ? AppColors.muted : Colors.white70, fontSize: 11)),
            ]),
            Icon(Icons.arrow_forward, color: fg, size: 20),
          ]),
        ),
      );

  Widget _promoCard(String title, String body, String cta, String img, Color color, VoidCallback onTap) => Container(
        decoration: BoxDecoration(color: AppColors.creamDeep, borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: serif(size: 20, color: color)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
            const SizedBox(height: 12),
            TextButton(onPressed: onTap, style: TextButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))), child: Text('$cta →', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          ]))),
          SizedBox(width: 120, height: 150, child: Image.asset(img, fit: BoxFit.cover)),
        ]),
      );
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _Trust(this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.terracotta, size: 20),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
        Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ]);
}
