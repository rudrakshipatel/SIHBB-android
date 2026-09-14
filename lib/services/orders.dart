import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'backend.dart';

/// One incoming order shown on the seller Orders screen.
class SellerOrder {
  final String orderId;
  final int amount;
  final String currency;
  final String buyer;
  final String artisan;
  final String paymentStatus;
  final String channel; // ONDC / Hastakala
  final String createdAt;
  final List<String> items;
  const SellerOrder(this.orderId, this.amount, this.currency, this.buyer,
      this.artisan, this.paymentStatus, this.channel, this.createdAt, this.items);

  factory SellerOrder.fromJson(Map j) => SellerOrder(
        (j['order_id'] ?? '').toString(),
        (j['amount'] as num?)?.round() ?? 0,
        (j['currency'] ?? 'INR').toString(),
        (j['buyer'] ?? 'Buyer').toString(),
        (j['artisan'] ?? '').toString(),
        (j['payment_status'] ?? '').toString(),
        (j['channel'] ?? 'ONDC').toString(),
        (j['created_at'] ?? '').toString(),
        ((j['items'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// Polls the backend for incoming orders and notifies listeners. Drives the
/// seller Orders tab, its unseen badge, and the "new order" banner.
class OrdersFeed extends ChangeNotifier {
  final List<SellerOrder> orders = [];
  int unseen = 0;
  int _lastNewCount = 0; // new orders detected on the most recent poll
  Timer? _timer;

  bool get configured => backendConfigured;
  int get lastNewCount => _lastNewCount;

  void start() {
    if (_timer != null || !backendConfigured) return;
    poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void markSeen() {
    if (unseen != 0) {
      unseen = 0;
      notifyListeners();
    }
  }

  Future<void> poll() async {
    if (!backendConfigured) return;
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/beckn/orders?limit=50'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = ((data['orders'] as List?) ?? const [])
          .map((e) => SellerOrder.fromJson(e as Map))
          .toList();
      final hadData = orders.isNotEmpty;
      final prevIds = orders.map((o) => o.orderId).toSet();
      final fresh = list.where((o) => !prevIds.contains(o.orderId)).length;
      orders
        ..clear()
        ..addAll(list);
      // Only flag as "new" after the first successful load (avoid flooding the
      // badge with pre-existing orders on launch).
      _lastNewCount = hadData ? fresh : 0;
      if (_lastNewCount > 0) unseen += _lastNewCount;
      notifyListeners();
    } catch (_) {/* keep current list */}
  }
}

final OrdersFeed ordersFeed = OrdersFeed();
