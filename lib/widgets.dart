import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';

class BrandLogo extends StatelessWidget {
  final bool dark;
  final double size;
  const BrandLogo({super.key, this.dark = false, this.size = 34});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
      ),
      const SizedBox(width: 8),
      RichText(
        text: TextSpan(style: TextStyle(fontFamily: kSerif, fontSize: size * 0.55, fontWeight: FontWeight.w700), children: [
          TextSpan(text: 'Hasta', style: TextStyle(color: dark ? const Color(0xFFEBDFCB) : AppColors.green)),
          TextSpan(text: 'kala', style: TextStyle(color: dark ? const Color(0xFFE08A5B) : AppColors.kala)),
        ]),
      ),
    ]);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: serif(size: 18, color: AppColors.green)),
        if (action != null)
          GestureDetector(onTap: onAction, child: Text(action!, style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w600, fontSize: 12))),
      ]),
    );
  }
}

class CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final double diameter;
  const CategoryTile(this.category, {super.key, required this.onTap, this.diameter = 62});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: diameter, height: diameter,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(category.image, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        SizedBox(width: diameter + 24, child: Text(category.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.15))),
      ]),
    );
  }
}

class ProductThumb extends StatelessWidget {
  final Product p;
  final double radius;
  const ProductThumb(this.p, {super.key, this.radius = 12});
  @override
  Widget build(BuildContext context) {
    if (p.imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(p.imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    }
    if (p.image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(p.image!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(colors: [p.c1, p.c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Text(p.name.split(' ').take(3).join(' '), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2, fontWeight: FontWeight.w600)),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product p;
  final VoidCallback onTap;
  const ProductCard(this.p, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 4 / 3, child: Stack(fit: StackFit.expand, children: [
            ProductThumb(p, radius: 0),
            if (p.b2bOnly)
              Positioned(left: 6, top: 6, child: _pill('B2B', AppColors.green)),
            Positioned(right: 6, bottom: 6, child: GestureDetector(
              onTap: () {
                if (!cart.any((x) => x.id == p.id)) cart.add(p);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'), duration: Duration(milliseconds: 900)));
              },
              child: Container(
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
              ),
            )),
          ])),
          Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${p.artisan} · ${p.location.split(',').last.trim()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(p.priceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800, fontSize: 13))),
            ]),
          ])),
        ]),
      ),
    );
  }
}

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
    );

class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const Sparkline(this.data, {super.key, this.color = AppColors.greenSoft});
  @override
  Widget build(BuildContext context) => SizedBox(height: 26, child: CustomPaint(size: Size.infinite, painter: _SparkPainter(data, color)));
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - (data[i] / (maxV == 0 ? 1 : maxV)) * (size.height - 3) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data;
}

class ProfileRing extends StatelessWidget {
  final int pct;
  const ProfileRing(this.pct, {super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84, height: 84,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: 84, height: 84, child: CustomPaint(painter: _RingPainter(pct))),
        Text('$pct%', style: serif(size: 20, color: AppColors.green)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int pct;
  _RingPainter(this.pct);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final bg = Paint()..color = const Color(0xFFE7E2D4)..strokeWidth = 9..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fg = Paint()..color = AppColors.green..strokeWidth = 9..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    final sweep = 6.28318 * (pct / 100);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}

/// A card wrapper with padding.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}
