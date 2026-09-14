import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data.dart';
import 'backend.dart';

/// ONDC / Beckn checkout via the FastAPI BPP. Runs select → init → confirm on
/// the backend and returns the order + ONDC-native payment. Requires
/// BACKEND_URL (the FastAPI service that hosts the Beckn BPP).
bool get becknConfigured => backendConfigured;

class BecknOrder {
  final String orderId;
  final int amount;
  final String currency;
  final String paymentStatus; // ONDC payment.status (e.g. PAID)
  final String upiLink;
  final String transactionId;
  final String bppId;
  final String domain;
  const BecknOrder(this.orderId, this.amount, this.currency, this.paymentStatus,
      this.upiLink, this.transactionId, this.bppId, this.domain);
}

Future<BecknOrder> becknCheckout(List<Product> items, {String buyer = 'Buyer'}) async {
  final body = jsonEncode({
    'items': [
      for (final p in items)
        {'id': p.id, 'title': p.name, 'price': p.price, 'qty': 1}
    ],
    'buyer_name': buyer,
  });
  final res = await http
      .post(Uri.parse('$backendUrl/beckn/checkout'),
          headers: {'content-type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw Exception('ONDC checkout ${res.statusCode}: ${res.body}');
  }
  final d = jsonDecode(res.body) as Map<String, dynamic>;
  final pay = (d['payment'] as Map?) ?? const {};
  final beckn = (d['beckn'] as Map?) ?? const {};
  return BecknOrder(
    (d['order_id'] ?? '').toString(),
    (d['amount'] as num?)?.round() ?? 0,
    (d['currency'] ?? 'INR').toString(),
    (pay['status'] ?? '').toString(),
    (d['upi_link'] ?? '').toString(),
    (beckn['transaction_id'] ?? '').toString(),
    (beckn['bpp_id'] ?? '').toString(),
    (beckn['domain'] ?? '').toString(),
  );
}
