/// Error de una llamada a la API del servidor.
///
/// [statusCode] es `null` cuando la petición nunca llegó a completarse (sin
/// conexión, DNS, timeout): la UI lo usa para distinguir "el servidor
/// respondió que no" de "no hay forma de hablar con el servidor" (ver
/// capacidad `web-client`, comportamiento ante pérdida de conexión).
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  /// La sesión no es válida: 401. La UI la trata distinto de un error de
  /// guardado común (ver capacidad `user-accounts`, sesión expirada durante
  /// el uso).
  bool get isAuthError => statusCode == 401;

  /// La petición no llegó a completarse: sin conexión, o el servidor no
  /// respondió en absoluto.
  bool get isOffline => statusCode == null;

  @override
  String toString() => message;
}
