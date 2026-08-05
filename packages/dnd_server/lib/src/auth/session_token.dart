import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Genera un token de sesión opaco, criptográficamente aleatorio (256 bits).
/// Es lo único que ve el navegador, dentro de la cookie `httpOnly`.
String generateSessionToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// El servidor nunca guarda el token en claro: guarda este hash. Un volcado
/// de la base no alcanza para reconstruir sesiones válidas.
String hashSessionToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();
