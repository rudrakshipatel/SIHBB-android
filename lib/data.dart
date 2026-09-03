import 'package:flutter/material.dart';

class Category {
  final String name;
  final String image;
  final List<String> subs;
  const Category(this.name, this.image, this.subs);
}

class Product {
  final String id;
  final String name;
  final String nameLocal;
  final int price;
  final String category;
  final String sub;
  final String artisan;
  final String location;
  final String description;
  final String cultural;
  final List<String> materials;
  final Color c1;
  final Color c2;
  final bool b2bOnly;
  const Product({
    required this.id,
    required this.name,
    required this.nameLocal,
    required this.price,
    required this.category,
    required this.sub,
    required this.artisan,
    required this.location,
    required this.description,
    required this.cultural,
    required this.materials,
    required this.c1,
    required this.c2,
    this.b2bOnly = false,
  });
}

class Artisan {
  final String name;
  final String location;
  final String craft;
  final bool verified;
  final String bio;
  const Artisan(this.name, this.location, this.craft, this.verified, this.bio);
  String get initial => name.substring(0, 1);
}

const categories = <Category>[
  Category('Textiles, Garments & Embroidery', 'assets/cat-textiles.jpg',
      ['Textiles', 'Shawls', 'Saree', 'Stoles', 'Zari & Zardozi', 'Chikankari']),
  Category('Ceramics & Pottery', 'assets/cat-ceramics.jpg', ['Pottery', 'Ceramics']),
  Category('Decorative Arts & Handicrafts', 'assets/cat-decorative.jpg',
      ['Paintings / Wall Art', 'Metal Craft', 'Brassware', 'Metal Sculptures & Figurines', 'Folk & Tribal Art', 'Traditional Indian Paintings']),
  Category('Jewellery & Accessories', 'assets/cat-jewellery.jpg', ['Necklace', 'Earrings', 'Anklets', 'Bracelets', 'Others']),
  Category('Woodwork & Furniture', 'assets/cat-woodwork.jpg', ['Wooden Sculptures', 'Wooden Artifacts', 'Tables', 'Seating', 'Storage Furniture']),
  Category('Miscellaneous', 'assets/cat-misc.jpg', ['Religious & Cultural Items', 'Lamps & Lighting', 'Decorative Items']),
];

const _terra1 = Color(0xFFC2410C), _terra2 = Color(0xFF7C2D12);
const _silk1 = Color(0xFF3730A3), _silk2 = Color(0xFF831843);
const _brass1 = Color(0xFFD97706), _brass2 = Color(0xFF92400E);
const _red1 = Color(0xFF9F1239), _red2 = Color(0xFF701A75);
const _green1 = Color(0xFF065F46), _green2 = Color(0xFF064E3B);

const products = <Product>[
  Product(id: 'p1', name: 'Handcrafted Terracotta Decorative Elephant', nameLocal: 'टेराकोटा सजावटी हाथी', price: 650, category: 'Ceramics & Pottery', sub: 'Pottery', artisan: 'Rekha Devi', location: 'Gorakhpur, Uttar Pradesh', description: 'Eco-friendly terracotta elephant with hand-carved detailing, kiln-fired using traditional Gorakhpur techniques.', cultural: 'The elephant symbolises prosperity and is a signature of Gorakhpur’s GI-tagged terracotta tradition.', materials: ['Natural terracotta clay', 'Natural pigments'], c1: _terra1, c2: _terra2),
  Product(id: 'p2', name: 'Terracotta Festival Diya Set (Set of 12)', nameLocal: 'टेराकोटा दीया सेट', price: 240, category: 'Ceramics & Pottery', sub: 'Pottery', artisan: 'Rekha Devi', location: 'Gorakhpur, Uttar Pradesh', description: 'Twelve hand-shaped terracotta oil lamps, ideal for Diwali and festive decor.', cultural: 'Diyas symbolise the victory of light over darkness during Diwali.', materials: ['Natural terracotta clay'], c1: _brass1, c2: _brass2),
  Product(id: 'p3', name: 'Handloom Madurai Sungudi Cotton Saree', nameLocal: 'மதுரை சுங்குடி புடவை', price: 1850, category: 'Textiles, Garments & Embroidery', sub: 'Saree', artisan: 'Murugan Subramanian', location: 'Madurai, Tamil Nadu', description: 'Natural-dyed Sungudi cotton saree handwoven on a pit loom with tie-dye dot motifs.', cultural: 'Sungudi is a 300-year-old GI-tagged Madurai tie-dye tradition.', materials: ['Handspun cotton', 'Natural dyes'], c1: _silk1, c2: _silk2),
  Product(id: 'p4', name: 'Handwoven Cotton Stole with Temple Border', nameLocal: 'பருத்தி துண்டு', price: 480, category: 'Textiles, Garments & Embroidery', sub: 'Stoles', artisan: 'Murugan Subramanian', location: 'Madurai, Tamil Nadu', description: 'Lightweight handwoven cotton stole with a traditional temple-border motif.', cultural: 'A staple of South Indian handloom weaving.', materials: ['Handspun cotton'], c1: _brass1, c2: _brass2),
  Product(id: 'p5', name: 'Bankura Terracotta Horse (Medium)', nameLocal: 'বাঁকুড়া টেরাকোটা ঘোড়া', price: 1200, category: 'Ceramics & Pottery', sub: 'Pottery', artisan: 'Anita Pal', location: 'Bankura, West Bengal', description: 'The iconic long-necked Bankura horse, hand-built and open-kiln fired.', cultural: 'The Bankura horse is the emblem of Indian handicrafts — a GI-tagged Bengal craft.', materials: ['Terracotta clay'], c1: _terra1, c2: _terra2),
  Product(id: 'p6', name: 'Hand-Engraved Brass Oil Lamp', nameLocal: 'पीतल का दीपक', price: 950, category: 'Decorative Arts & Handicrafts', sub: 'Brassware', artisan: 'Imran Ansari', location: 'Moradabad, Uttar Pradesh', description: 'Traditional brass oil lamp with hand-engraved motifs, polished to a warm finish.', cultural: 'Brass lamps are central to Indian rituals and Moradabad’s celebrated metal craft.', materials: ['Brass alloy'], c1: _brass1, c2: _brass2),
  Product(id: 'p7', name: 'Engraved Brass Planter (Large)', nameLocal: 'पीतल का गमला', price: 2600, category: 'Decorative Arts & Handicrafts', sub: 'Brassware', artisan: 'Imran Ansari', location: 'Moradabad, Uttar Pradesh', description: 'Large engraved brass planter suited to indoor plants and hotel lobbies.', cultural: 'Made-to-order Moradabad brasswork for hospitality and interiors.', materials: ['Brass alloy'], c1: _brass2, c2: _brass1, b2bOnly: true),
  Product(id: 'p8', name: 'Handloom Banarasi Silk Dupatta with Zari', nameLocal: 'बनारसी सिल्क दुपट्टा', price: 2400, category: 'Textiles, Garments & Embroidery', sub: 'Textiles', artisan: 'Lakshmi Bai', location: 'Varanasi, Uttar Pradesh', description: 'Pure Banarasi silk dupatta handwoven with real zari brocade borders.', cultural: 'Banaras brocade weaving is a GI-tagged heritage craft of Varanasi.', materials: ['Mulberry silk', 'Zari'], c1: _red1, c2: _red2),
  Product(id: 'p9', name: 'Pure Banarasi Silk Saree (Katan)', nameLocal: 'बनारसी कातन साड़ी', price: 8500, category: 'Textiles, Garments & Embroidery', sub: 'Saree', artisan: 'Lakshmi Bai', location: 'Varanasi, Uttar Pradesh', description: 'Handwoven Katan silk Banarasi saree with intricate zari buti work.', cultural: 'A bridal heirloom textile of Varanasi’s weaving community.', materials: ['Katan silk', 'Zari'], c1: _green1, c2: _green2),
];

const artisans = <Artisan>[
  Artisan('Rekha Devi', 'Gorakhpur, Uttar Pradesh', 'Terracotta Pottery', true, 'Third-generation terracotta potter shaping festival lamps and figurines from local river clay.'),
  Artisan('Murugan Subramanian', 'Madurai, Tamil Nadu', 'Handloom Weaving', true, 'Handloom weaver of Sungudi cotton sarees using natural dyes on a pit loom.'),
  Artisan('Imran Ansari', 'Moradabad, Uttar Pradesh', 'Brass Metalware', true, 'Brass artisan engraving lamps, planters and tableware for four decades.'),
  Artisan('Lakshmi Bai', 'Varanasi, Uttar Pradesh', 'Banarasi Silk', true, 'Banarasi silk weaver specialising in zari brocade dupattas and sarees.'),
];

// ---- Seller dashboard demo figures (mirror the web dashboard) ----
class Stat {
  final IconData icon;
  final String label;
  final String value;
  final String delta;
  final List<double> spark;
  const Stat(this.icon, this.label, this.value, this.delta, this.spark);
}

const dashboardStats = <Stat>[
  Stat(Icons.visibility_outlined, 'Product Views', '1,248', '↑ 32%', [3, 4, 3, 6, 5, 8, 7, 9]),
  Stat(Icons.chat_bubble_outline, 'Inquiries', '28', '↑ 40%', [1, 2, 2, 3, 4, 3, 5, 6]),
  Stat(Icons.shopping_bag_outlined, 'Orders', '12', '↑ 20%', [1, 1, 2, 2, 3, 3, 4, 5]),
  Stat(Icons.currency_rupee, 'Total Earnings', '₹18,650', '↑ 28%', [2, 3, 4, 4, 6, 7, 8, 10]),
];

class ProfileTask {
  final String label;
  final bool done;
  const ProfileTask(this.label, this.done);
}

const profileTasks = <ProfileTask>[
  ProfileTask('Add profile picture', true),
  ProfileTask('Add your craft story', true),
  ProfileTask('Add contact details', true),
  ProfileTask('Add 5+ products', true),
  ProfileTask('Get verified', false),
];

class Inquiry {
  final String buyer;
  final String type; // B2B / B2C
  final String title;
  final String meta;
  final String when;
  final bool isNew;
  const Inquiry(this.buyer, this.type, this.title, this.meta, this.when, this.isNew);
}

const inquiries = <Inquiry>[
  Inquiry('Giftwell Corporate', 'B2B', '500 units · Terracotta Elephant', 'Budget ₹600–₹900', '10 mins ago', true),
  Inquiry('Boutique Retail', 'B2B', '100 units · Decorative Pot', 'Budget ₹800–₹1,200', '1 hour ago', true),
  Inquiry('Meera Nair', 'B2C', 'Terracotta diya collection', 'Interested in bulk diyas', '2 hours ago', false),
];

class Insight {
  final String title;
  final String detail;
  final String metric;
  const Insight(this.title, this.detail, this.metric);
}

const insights = <Insight>[
  Insight('Terracotta Diyas', 'received the most views this month', '842'),
  Insight('Jaipur & Delhi', 'showed the highest interest', '68%'),
  Insight('Corporate Gifting', 'is your top matching segment', '92%'),
];

class Exhibition {
  final String name, location, dates, status;
  final int scans, visitors, inqs;
  const Exhibition(this.name, this.location, this.dates, this.status, this.scans, this.visitors, this.inqs);
}

const exhibitions = <Exhibition>[
  Exhibition('Surajkund International Crafts Mela', 'Faridabad, Haryana', '1 – 16 Feb 2026', 'Ended', 230, 156, 18),
  Exhibition('Dilli Haat Artisan Showcase', 'INA, New Delhi', '10 – 25 Sep 2026', 'Upcoming', 0, 0, 0),
];

class Order {
  final String product, buyer, status;
  final int amount;
  const Order(this.product, this.buyer, this.status, this.amount);
}

const orders = <Order>[
  Order('Terracotta Festival Diya Set', 'Giftwell Corporate', 'Delivered', 4800),
  Order('Terracotta Decorative Elephant', 'Meera Nair', 'Delivered', 1300),
  Order('Terracotta Decorative Elephant', 'Meera Nair', 'Shipped', 650),
  Order('Terracotta Festival Diya Set', 'Giftwell Corporate', 'Delivered', 2400),
];

class BuyerInquiry {
  final String product, artisan, status, when;
  const BuyerInquiry(this.product, this.artisan, this.status, this.when);
}

const myInquiries = <BuyerInquiry>[
  BuyerInquiry('Handloom Banarasi Silk Dupatta', 'Lakshmi Bai', 'Responded', 'yesterday'),
  BuyerInquiry('Terracotta Decorative Elephant', 'Rekha Devi', 'Quoted', '2 days ago'),
];

const faqs = <List<String>>[
  ['How do I inquire about a product?', 'Open any product and tap “Inquire” for a question or “Request Quote” for a bulk order. The artisan is notified and replies with details or a quote.'],
  ['Are the artisans verified?', 'Yes — verified artisans carry a green tick. We check identity and craft authenticity before publishing.'],
  ['How is a fair price decided?', 'Prices are cost-plus (materials + labour + a guaranteed 20% artisan margin) — never a fabricated market price.'],
  ['Do you ship across India?', 'Yes. Delivery and logistics are arranged after an inquiry is confirmed with the artisan.'],
];

String rupee(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₹${b.toString()}';
}
