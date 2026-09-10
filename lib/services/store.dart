import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../data.dart';
import '../theme.dart';

/// Offline persistence for artisan-published listings (SQLite via sqflite).
/// Chosen over Drift to avoid build_runner codegen on the beta SDK; the schema
/// is a simple mirror that a later ONDC/Supabase sync layer can read from.
Database? _db;

Future<void> initStore() async {
  final path = '${await getDatabasesPath()}/hastakala.db';
  _db = await openDatabase(
    path,
    version: 3,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE products(
          id TEXT PRIMARY KEY,
          name TEXT, name_local TEXT, price INTEGER,
          category TEXT, sub TEXT, artisan TEXT, location TEXT,
          description TEXT, description_local TEXT, cultural TEXT,
          materials TEXT, segments TEXT,
          image BLOB, created_at INTEGER
        )''');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
    },
    onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        await db.execute('ALTER TABLE products ADD COLUMN description_local TEXT');
      }
      if (oldV < 3) {
        await db.execute('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)');
      }
    },
  );
}

/// Small key/value store for local settings (seller identity, etc.).
Future<String?> getSetting(String key) async {
  final db = _db;
  if (db == null) return null;
  final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
  return rows.isEmpty ? null : rows.first['value'] as String?;
}

Future<void> setSetting(String key, String value) async {
  final db = _db;
  if (db == null) return;
  await db.insert('settings', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
}

/// Loads persisted listings into the in-memory [userProducts] (oldest first,
/// so [allProducts] shows newest first).
Future<void> loadUserProducts() async {
  final db = _db;
  if (db == null) return;
  final rows = await db.query('products', orderBy: 'created_at ASC');
  userProducts
    ..clear()
    ..addAll(rows.map(_fromRow));
}

/// Persists one published listing.
Future<void> saveUserProduct(Product p) async {
  final db = _db;
  if (db == null) return;
  await db.insert('products', {
    'id': p.id,
    'name': p.name,
    'name_local': p.nameLocal,
    'price': p.price,
    'category': p.category,
    'sub': p.sub,
    'artisan': p.artisan,
    'location': p.location,
    'description': p.description,
    'description_local': p.descriptionLocal,
    'cultural': p.cultural,
    'materials': jsonEncode(p.materials),
    'segments': jsonEncode(p.segments),
    'image': p.imageBytes,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

Product _fromRow(Map<String, Object?> r) {
  List<String> list(Object? v) {
    if (v is! String || v.isEmpty) return const [];
    try {
      return (jsonDecode(v) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  return Product(
    id: r['id'] as String,
    name: (r['name'] as String?) ?? 'Untitled',
    nameLocal: (r['name_local'] as String?) ?? '',
    price: (r['price'] as int?) ?? 0,
    category: (r['category'] as String?) ?? '',
    sub: (r['sub'] as String?) ?? '',
    artisan: (r['artisan'] as String?) ?? '',
    location: (r['location'] as String?) ?? '',
    description: (r['description'] as String?) ?? '',
    descriptionLocal: (r['description_local'] as String?) ?? '',
    cultural: (r['cultural'] as String?) ?? '',
    materials: list(r['materials']),
    segments: list(r['segments']),
    imageBytes: r['image'] as Uint8List?,
    c1: AppColors.green,
    c2: AppColors.terracotta,
  );
}
