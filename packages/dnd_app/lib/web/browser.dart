// Único punto de contacto con el navegador para lo que no tiene equivalente
// en Flutter puro: navegar la pestaña entera (login/logout) y disparar una
// descarga de bytes en memoria. El resto de la aplicación importa este
// archivo, nunca `dart:html` directamente.
//
// La implementación real (`browser_web.dart`) solo se resuelve al compilar
// para web; en cualquier otra plataforma —incluida la VM que corre
// `flutter test`— se usa `browser_stub.dart`, para que el árbol de imports
// de `dart:html` no rompa la compilación fuera del navegador (mismo patrón
// que `content_pack_loader_stub.dart` en `dnd_engine`).
export 'browser_stub.dart' if (dart.library.html) 'browser_web.dart';
