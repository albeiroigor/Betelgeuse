import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const clientId = String.fromEnvironment('BETELGEUSE_CLIENT_ID');

class DeviceCode {
  final String deviceCode, userCode, uri;
  final int interval, expiresIn;
  DeviceCode(
    this.deviceCode,
    this.userCode,
    this.uri,
    this.interval,
    this.expiresIn,
  );
}

Future<Map<String, dynamic>> _post(
  String path,
  Map<String, String> body,
) async {
  final http.Response r;
  try {
    r = await http
        .post(
          Uri.https('github.com', path),
          headers: {'Accept': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw 'GitHub tardó demasiado en responder. Revisa tu conexión.';
  }
  if (r.statusCode < 200 || r.statusCode >= 300) {
    throw 'GitHub respondió ${r.statusCode}.';
  }
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<DeviceCode> startLogin() async {
  final j = await _post('/login/device/code', {
    'client_id': clientId,
    'scope': 'project repo read:org',
  });
  if (j['device_code'] == null) {
    throw j['error_description'] ?? 'No se pudo iniciar el login.';
  }
  return DeviceCode(
    j['device_code'],
    j['user_code'],
    j['verification_uri'],
    j['interval'],
    j['expires_in'],
  );
}

Future<String> waitForToken(DeviceCode d, bool Function() cancelled) async {
  var wait = d.interval;
  final end = DateTime.now().add(Duration(seconds: d.expiresIn));
  while (DateTime.now().isBefore(end)) {
    await Future.delayed(Duration(seconds: wait));
    if (cancelled()) throw 'Cancelado';
    final j = await _post('/login/oauth/access_token', {
      'client_id': clientId,
      'device_code': d.deviceCode,
      'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
    });
    if (j['access_token'] != null) {
      return j['access_token'];
    }
    switch (j['error']) {
      case 'authorization_pending':
        break;
      case 'slow_down':
        wait += 5;
        break;
      case 'access_denied':
        throw 'Rechazaste la autorización.';
      default:
        throw j['error_description'] ?? 'El código expiró. Intenta de nuevo.';
    }
  }
  throw 'El código expiró. Intenta de nuevo.';
}
