/// Logins OIDC en curso, indexados por su `state`, con vencimiento y tope.
///
/// Guardar el flujo entre `/auth/login` y `/auth/callback` es obligatorio (ahí
/// vive el verificador PKCE), pero un login que nunca vuelve no tiene quien lo
/// borre: sin vencimiento ni tope, cada `GET /auth/login` dejaba una entrada
/// para siempre y el mapa crecía con el uso normal —y mucho más rápido ante un
/// cliente en bucle o un pedido repetido a mano— hasta agotar la memoria del
/// proceso.
///
/// Genérica en [T] para poder probar la política de retención sin construir un
/// `Flow` de `openid_client`, que exige un emisor OIDC real.
class PendingLogins<T> {
  /// Cuánto puede tardar alguien entre pedir el login y volver del proveedor.
  /// Generoso a propósito: incluye escribir la contraseña, un segundo factor y
  /// un cambio de contraseña forzado.
  final Duration ttl;

  /// Techo duro de logins simultáneos en curso. Muy por encima de lo que
  /// necesita una instalación de una mesa, y lo que impide que un cliente que
  /// solo pide `/auth/login` en bucle haga crecer el mapa sin fin.
  final int maxEntries;

  final DateTime Function() _now;
  final Map<String, _Pending<T>> _entries = {};

  PendingLogins({
    this.ttl = const Duration(minutes: 15),
    this.maxEntries = 500,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  int get length => _entries.length;

  /// Registra el flujo de [state]. Aprovecha para barrer lo ya vencido: no
  /// hace falta un temporizador aparte porque este es el único punto por el
  /// que el mapa crece.
  void add(String state, T value) {
    final ahora = _now();
    _entries.removeWhere((_, pending) => pending.hasExpired(ahora));

    // `Map` conserva el orden de inserción, así que la primera clave es
    // siempre la del login en curso más viejo.
    while (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }

    _entries[state] = _Pending(value, ahora.add(ttl));
  }

  /// Canjea el flujo de [state] y lo saca del mapa: un `state` sirve una sola
  /// vez. Devuelve `null` si nunca existió, si ya se usó o si venció, tres
  /// casos que el llamador trata igual (petición no autenticada).
  T? remove(String state) {
    final pending = _entries.remove(state);
    if (pending == null || pending.hasExpired(_now())) return null;
    return pending.value;
  }
}

class _Pending<T> {
  final T value;
  final DateTime expiresAt;

  const _Pending(this.value, this.expiresAt);

  bool hasExpired(DateTime ahora) => !ahora.isBefore(expiresAt);
}
