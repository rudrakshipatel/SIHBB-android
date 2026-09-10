import 'dart:math';

import 'store.dart';

/// A per-device seller identity so each installed app publishes as a distinct
/// artisan (no login needed). Stored locally; the user + artisan rows are
/// created in Supabase on first publish. This is a lightweight stand-in for
/// full Supabase Auth — fine for the demo, swap for auth.uid() later.
class SellerIdentity {
  final String userId; // uuid, references users.id
  final String artisanId; // uuid, references artisans.id
  final String name;
  final String location;
  const SellerIdentity(this.userId, this.artisanId, this.name, this.location);
}

SellerIdentity _identity =
    const SellerIdentity('', '', 'Artisan', 'India');

SellerIdentity get identity => _identity;

/// A RFC-4122 v4 UUID from a secure RNG (no package dependency).
String uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// Loads the device identity, creating (and persisting) stable UUIDs on first
/// run. Call after initStore().
Future<void> loadIdentity() async {
  var uid = await getSetting('seller_user_id');
  var aid = await getSetting('seller_artisan_id');
  var name = await getSetting('seller_name');
  var loc = await getSetting('seller_location');
  if (uid == null || aid == null) {
    uid = uuidV4();
    aid = uuidV4();
    name ??= 'Artisan ${aid.substring(0, 4)}';
    loc ??= 'India';
    await setSetting('seller_user_id', uid);
    await setSetting('seller_artisan_id', aid);
    await setSetting('seller_name', name);
    await setSetting('seller_location', loc);
  }
  _identity = SellerIdentity(uid, aid, name ?? 'Artisan', loc ?? 'India');
}

/// Updates the artisan's display name / location (persisted locally; pushed to
/// Supabase on the next publish).
Future<void> updateSellerProfile({String? name, String? location}) async {
  final n = (name ?? _identity.name).trim();
  final l = (location ?? _identity.location).trim();
  await setSetting('seller_name', n);
  await setSetting('seller_location', l);
  _identity = SellerIdentity(_identity.userId, _identity.artisanId,
      n.isEmpty ? 'Artisan' : n, l.isEmpty ? 'India' : l);
}
