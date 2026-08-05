const String sessionCookieName = 'dnd_session';

/// Cabecera `Set-Cookie` para instalar la sesión. `httpOnly` la esconde de
/// JavaScript, `Secure` exige HTTPS (el túnel siempre lo hace) y `SameSite`
/// evita que un sitio de terceros pueda arrastrarla en una petición cruzada.
/// MUST NOT faltar ninguno de los tres: son justamente la garantía de que el
/// navegador nunca custodia nada más que un puntero opaco.
String buildSessionCookieHeader(String token, {required Duration maxAge}) {
  return '$sessionCookieName=$token; '
      'HttpOnly; Secure; SameSite=Lax; Path=/; '
      'Max-Age=${maxAge.inSeconds}';
}

/// Cabecera para borrar la cookie (cierre de sesión): mismo nombre y
/// atributos, con el valor vaciado y `Max-Age=0`.
String buildExpiredSessionCookieHeader() {
  return '$sessionCookieName=; HttpOnly; Secure; SameSite=Lax; Path=/; '
      'Max-Age=0';
}

/// Extrae el token de sesión de una cabecera `Cookie` entrante, o `null` si
/// no está presente.
///
/// Se corta por el **primer** `=`, no por todos: según RFC 6265 el nombre es
/// lo que va antes de ese primer signo y el valor es todo el resto, `=`
/// incluidos. Importa porque el token que emite `generateSessionToken` es
/// base64url de 32 bytes y por lo tanto SIEMPRE termina en un `=` de relleno:
/// partir por todos los `=` descartaba en silencio cada cookie de sesión, toda
/// petición se respondía como no autenticada y el cliente quedaba en un ciclo
/// infinito de login.
String? readSessionToken(String? cookieHeader) {
  if (cookieHeader == null) return null;
  for (final part in cookieHeader.split(';')) {
    final trimmed = part.trim();
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    if (trimmed.substring(0, separator) != sessionCookieName) continue;
    return trimmed.substring(separator + 1);
  }
  return null;
}
