import 'package:shelf/shelf.dart';

/// Nombres de archivo que determinan qué versión del cliente carga el
/// navegador: MUST NOT servirse con una caché que sobreviva a un despliegue,
/// o una recarga normal seguiría mostrando el bundle viejo (ver capacidad
/// `self-hosted-deployment`, requisito "Entrega correcta de nuevas versiones
/// del cliente web").
const _entryPointNames = {
  'index.html',
  'flutter_service_worker.js',
  'flutter_bootstrap.js',
  'version.json',
};

bool _isEntryPoint(String path) =>
    path.isEmpty || _entryPointNames.contains(path.split('/').last);

/// Envuelve el handler de archivos estáticos del build web para fijar
/// `Cache-Control`: los puntos de entrada (que deciden la versión) nunca se
/// cachean, y el resto de los recursos —con huella de contenido en el nombre
/// que arma `flutter build web`— se cachean por un año sin revalidar.
Middleware get webCacheHeadersMiddleware => (Handler inner) {
  return (Request request) async {
    final response = await inner(request);
    final cacheControl = _isEntryPoint(request.url.path)
        ? 'no-cache'
        : 'public, max-age=31536000, immutable';
    return response.change(headers: {'cache-control': cacheControl});
  };
};
