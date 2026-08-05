// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// `dart:html` sigue siendo la única forma de navegar la pestaña y descargar
// un blob sin agregar `package:web` solo para dos llamadas. El lint que evita
// librerías web fuera de plugins asume que este archivo se compila también
// para las demás plataformas: no es el caso, es el lado `_web.dart` de una
// importación condicional (ver `browser.dart`/`browser_stub.dart`), así que
// nunca entra al build de Windows.
import 'dart:html' as html;
import 'dart:typed_data';

/// Único punto de contacto con el navegador para lo que no tiene equivalente
/// en Flutter puro: navegar la pestaña entera (login/logout) y disparar una
/// descarga de bytes en memoria. El resto de la aplicación no importa
/// `dart:html` directamente.

/// Navega la pestaña completa a [path] (ruta relativa al origen actual). Se
/// usa para `/auth/login`: una petición `fetch` seguiría el 302 del lado del
/// cliente y nunca mostraría la pantalla de inicio de sesión del proveedor
/// OIDC, así que esto tiene que ser una navegación real, no una llamada de
/// `ApiClient`.
void redirectTo(String path) {
  html.window.location.assign(path);
}

/// Descarga [bytes] como un archivo, sin exponer ninguna ruta del servidor
/// (ver capacidad `web-client`, exportación de un personaje): crea un enlace
/// efímero a un blob en memoria y lo "clickea" mediante programación.
void downloadBytes(
  Uint8List bytes, {
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
