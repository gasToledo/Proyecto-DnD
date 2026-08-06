{{flutter_js}}
{{flutter_build_config}}

// `main.dart.js` se pide con la huella del build en la query.
//
// El 5 de agosto de 2026 Cloudflare sirvió ese archivo con
// `public, max-age=31536000, immutable` y esa cabecera llegó a los navegadores
// que abrieron la aplicación ese día: quedaron clavados un año en un bundle que
// ya no entendía los assets frescos ("Tipo de efecto desconocido"). El origen se
// arregló (ver `webCacheHeadersMiddleware`), pero una caché envenenada de un
// intermediario no se puede desalojar desde el servidor: el único que decide qué
// entrada usar es el navegador, y solo cambia de entrada si cambia la URL.
//
// `flutter_service_worker_version` ya es un valor distinto por build, así que
// sirve de huella sin inventar otra. `flutter_bootstrap.js` se sirve
// `private, no-cache` y revalida siempre, así que cada despliegue entrega una
// query nueva y ningún navegador puede reusar el bundle viejo.
const _mainJsVersion = {{flutter_service_worker_version}};
// `builds` trae entradas vacías además de la real, y el cargador resuelve un
// `mainJsPath` ausente a "main.dart.js" por su cuenta: escribirle la query a una
// entrada sin ruta la dejaría pidiendo "undefined?v=...".
if (_mainJsVersion) {
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) build.mainJsPath += "?v=" + _mainJsVersion;
  }
}

_flutter.loader.load();
