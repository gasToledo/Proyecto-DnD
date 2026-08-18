import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Alfabeto del código: 30 símbolos sin los pares que se confunden al leer o
/// al dictar (`I`/`1`, `L`, `O`/`0`, `U`/`V`). El código se pasa por WhatsApp o
/// en voz alta en la mesa, así que un carácter ambiguo es un código que no
/// entra y una persona convencida de que la app falla.
const String shareCodeAlphabet = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';

/// Largo del código, sin contar el guion de presentación.
const int shareCodeLength = 8;

/// Genera un código de un solo uso para compartir un personaje.
///
/// Ocho caracteres del alfabeto de arriba son unos 39 bits: de sobra contra un
/// adivinador que solo puede probar por HTTP, que es el único ataque posible
/// porque la base guarda el hash y no el código.
///
/// Se devuelve ya con guion (`XXXX-XXXX`) porque es la forma en que se muestra
/// y se copia; [normalizeShareCode] lo saca antes de compararlo.
String generateShareCode() {
  final random = Random.secure();
  final chars = [
    for (var i = 0; i < shareCodeLength; i++)
      shareCodeAlphabet[random.nextInt(shareCodeAlphabet.length)],
  ];
  final half = shareCodeLength ~/ 2;
  return '${chars.sublist(0, half).join()}-${chars.sublist(half).join()}';
}

/// Deja el código en su forma canónica para compararlo.
///
/// El DM lo pega como le llegó: con guion o sin él, en minúscula, con espacios
/// de más al copiar de un chat. Todo eso es el mismo código, así que se
/// normaliza antes de hashear en vez de exigirle una forma exacta.
String normalizeShareCode(String raw) {
  final buffer = StringBuffer();
  for (final char in raw.toUpperCase().split('')) {
    if (shareCodeAlphabet.contains(char)) buffer.write(char);
  }
  return buffer.toString();
}

/// El servidor nunca guarda el código en claro: guarda este hash, igual que
/// con los tokens de sesión.
String hashShareCode(String code) =>
    sha256.convert(utf8.encode(normalizeShareCode(code))).toString();
