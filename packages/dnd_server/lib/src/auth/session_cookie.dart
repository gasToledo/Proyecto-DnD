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
String? readSessionToken(String? cookieHeader) {
  if (cookieHeader == null) return null;
  for (final part in cookieHeader.split(';')) {
    final pair = part.trim().split('=');
    if (pair.length == 2 && pair[0] == sessionCookieName) {
      return pair[1];
    }
  }
  return null;
}
