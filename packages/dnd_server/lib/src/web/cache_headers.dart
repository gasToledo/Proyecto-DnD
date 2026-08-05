import 'package:shelf/shelf.dart';

/// `Cache-Control` con el que se sirve todo el build web.
///
/// **Nada de lo que emite `flutter build web` lleva huella de contenido en el
/// nombre**: `main.dart.js`, `flutter_bootstrap.js`, `assets/...` y
/// `canvaskit/...` se llaman igual en una versión y en la siguiente. Por eso
/// ningún archivo de este build puede declararse `immutable` ni cachearse a
/// largo plazo: hacerlo dejaba a cualquier navegador que ya hubiera abierto la
/// aplicación clavado un año en el bundle viejo, aunque `index.html` llegara
/// fresco (ver capacidad `self-hosted-deployment`, requisito "Entrega correcta
/// de nuevas versiones del cliente web").
///
/// `no-cache` no quiere decir "no guardar": el navegador guarda igual y
/// revalida antes de usar. Como `shelf_static` responde `Last-Modified` y
/// entiende `If-Modified-Since`, una recarga sin despliegue nuevo se resuelve
/// con un 304 sin cuerpo; recién cuando se reconstruye la imagen cambia la
/// fecha y baja el archivo entero.
///
/// `private` está por Cloudflare, que es la única caché compartida en el
/// camino. Con `no-cache` a secas el borde igual almacenaba los `.js` y
/// reescribía la cabecera hacia el navegador a `max-age=14400`, así que un
/// despliegue tardaba hasta cuatro horas en llegar aunque el origen pidiera
/// revalidación. Estos archivos son de *esta* versión del despliegue y el
/// único que decide cuál corresponde es este servidor, así que ningún
/// intermediario debe quedárselos.
const String webCacheControl = 'private, no-cache';

/// Fija [webCacheControl] en todo lo que sirve el handler de archivos
/// estáticos del build web. Es deliberadamente uniforme: mientras los nombres
/// no lleven huella de contenido, distinguir "punto de entrada" de "recurso"
/// solo sirve para volver a desincronizar el `index.html` de su bundle.
Middleware get webCacheHeadersMiddleware => (Handler inner) {
  return (Request request) async {
    final response = await inner(request);
    return response.change(headers: {'cache-control': webCacheControl});
  };
};
