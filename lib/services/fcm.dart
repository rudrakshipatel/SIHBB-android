import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'backend.dart';

/// Background isolate handler — the system tray shows notifications with a
/// `notification` payload automatically; nothing to do here.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {}

/// Initialises Firebase Cloud Messaging: asks permission, gets the device
/// token, and registers it with the backend so order pushes reach this device
/// even when the app is closed. Safe no-op if FCM/backend is unavailable.
Future<void> initFcm() async {
  if (!backendConfigured) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    final token = await fm.getToken();
    if (token != null && token.isNotEmpty) await _register(token);
    fm.onTokenRefresh.listen(_register);
  } catch (_) {
    // FCM not available on this device/build — the app still works.
  }
}

Future<void> _register(String token) async {
  try {
    await http
        .post(Uri.parse('$backendUrl/beckn/register-token'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'token': token}))
        .timeout(const Duration(seconds: 15));
  } catch (_) {}
}
