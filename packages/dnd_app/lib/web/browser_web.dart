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

/// Abre [url] en una pestaña nueva, para los enlaces que el jugador guarda en
/// el Diario.
///
/// `noopener,noreferrer` corta el acceso de la página abierta a
/// `window.opener`: sin eso, un sitio enlazado desde una entrada podría
/// redirigir la pestaña de la aplicación a donde quisiera.
///
/// **Quien llama valida el esquema** (`_openableLink`, en el Diario): un
/// `javascript:` llegando hasta acá se ejecutaría en el origen de la propia
/// aplicación. Esta función es el mecanismo, no la política, y hoy tiene un
/// solo llamador.
void openInNewTab(String url) {
  html.window.open(url, '_blank', 'noopener,noreferrer');
}
