## 1. Desbloquear la compilación web

- [x] 1.1 Sacar `loadFromDirectory` de la ruta importable por web en
      `dnd_engine` (hoy `lib/dnd_engine.dart` exporta `content_repository.dart`,
      que importa `dart:io`), conservando el punto de entrada para pruebas
- [x] 1.2 Verificar que las 47 llamadas a `loadFromDirectory` de las pruebas de
      ambos paquetes siguen pasando sin cambios de comportamiento
- [x] 1.3 Añadir una prueba o comprobación de compilación que falle si `dart:io`
      vuelve a entrar en la superficie web del motor
- [x] 1.4 Confirmar con una compilación web mínima que el motor ya compila para
      navegador

## 2. Retratos como claves opacas en el dominio

- [x] 2.1 Redefinir `Character.portraitPaths` como claves opacas de retrato y
      actualizar su documentación en `character.dart`
- [x] 2.2 Escribir la prueba de regresión que falla al leer un personaje
      histórico con rutas absolutas, antes de implementar la migración
- [x] 2.3 Implementar la migración de esquema versionada de rutas a claves y
      subir `currentSchemaVersion`
- [x] 2.4 Reemplazar los tres renderizados atados al disco
      (`dashboard_widgets.dart:235`, `sheet_navigation.dart:55`,
      `sheet_widgets.dart:40`) por un único widget que resuelva la clave
- [x] 2.5 Verificar que un personaje exportado ya no contiene ninguna ruta del
      sistema de archivos

## 3. Paquete del servidor

- [x] 3.1 Crear `packages/dnd_server` como paquete Dart con `dnd_engine` como
      dependencia de ruta
- [x] 3.2 Establecer el esqueleto HTTP con enrutado, manejo de errores y
      apagado ordenado
- [x] 3.3 Exponer el punto de comprobación de salud del servicio
- [x] 3.4 Añadir los comandos de formato, análisis y pruebas del paquete al
      README y a `CLAUDE.md`
- [x] 3.5 Definir la carga de configuración por entorno, sin valores por defecto
      que contengan secretos

## 4. Persistencia en PostgreSQL

- [x] 4.1 Definir el esquema con el documento en `jsonb`, columnas generadas y
      clave primaria compuesta `(user_id, id)`
- [x] 4.2 Establecer el mecanismo de migraciones de base de datos y su ejecución
      al arrancar
- [x] 4.3 Implementar el repositorio de personajes: alta, lectura, listado,
      actualización y baja, con propiedad por cuenta
- [x] 4.4 Aplicar la migración secuencial de documentos históricos al leer, y el
      rechazo sin escritura de versiones futuras
- [x] 4.5 Implementar la escritura multi-documento en una única transacción
- [x] 4.6 Implementar los repositorios de homebrew y de ajustes por cuenta
- [x] 4.7 Implementar la asignación de un identificador libre cuando el
      solicitado ya existe en la cuenta
- [x] 4.8 Probar que un fallo a mitad de una escritura por lotes no deja
      documentos modificados
- [x] 4.9 Probar que el estado de combate sobrevive a ediciones de equipo,
      conjuros y nivel

## 5. Autenticación y aislamiento de cuentas

- [ ] 5.1 Levantar Zitadel con su propia base y registrar la aplicación cliente
      (acción de infraestructura: pendiente hasta el docker-compose de la
      sección 10 y su registro manual en la consola de Zitadel)
- [x] 5.2 Implementar el flujo Authorization Code con PKCE del lado del servidor
- [x] 5.3 Emitir la sesión como cookie `httpOnly`, `Secure` y `SameSite`, y
      conservar los tokens solo en el servidor
- [x] 5.4 Implementar el cierre de sesión y la invalidación de la sesión de
      servidor
- [x] 5.5 Mapear el sujeto OIDC verificado a una fila de usuario propia
- [x] 5.6 Aplicar el filtro de propiedad a toda lectura y escritura de datos
- [x] 5.7 Escribir las pruebas de acceso cruzado: una cuenta que conoce el
      identificador de otra no obtiene el recurso ni confirmación de que existe
- [x] 5.8 Probar que una aserción con emisor o firma inválidos se rechaza
- [x] 5.9 Verificar que tras iniciar sesión no hay tokens del proveedor en el
      almacenamiento del navegador

## 6. Almacenamiento y servido de retratos

- [x] 6.1 Definir la interfaz de almacenamiento de blobs de retrato
- [x] 6.2 Implementarla sobre volumen de disco, trasladando
      `portrait_storage.dart` al servidor
- [x] 6.3 Exponer el servido de retratos del mismo origen, autorizado por la
      sesión
- [x] 6.4 Validar tipo y tamaño de las imágenes entrantes contra el límite
      configurado
- [x] 6.5 Rechazar claves de retrato que intenten salir del espacio de la cuenta
- [x] 6.6 Probar que un retrato ajeno responde como inexistente y que uno sin
      sesión no se entrega
- [x] 6.7 Probar que los retratos sobreviven al reinicio de los contenedores

## 7. Generación de retratos con IA en el servidor

- [x] 7.1 Trasladar `lib/ai/` de `dnd_app` a `dnd_server` conservando la
      inyección de cliente HTTP que ya tienen los servicios
- [x] 7.2 Cargar las credenciales de proveedor desde la configuración del
      servidor
- [x] 7.3 Exponer el punto de generación de la API propia, incluida la variante
      con imagen de referencia
- [x] 7.4 Ocultar como seleccionable todo proveedor sin credenciales
      configuradas
- [x] 7.5 Degradar al proveedor predeterminado ante un proveedor retirado o
      desconocido, conservando el resto de los ajustes
- [x] 7.6 Descartar respuestas ilegibles o fallidas sin dejar un retrato parcial
      asociado
- [x] 7.7 Implementar la subida de un retrato propio, disponible aunque no haya
      proveedores configurados
- [x] 7.8 Verificar que ninguna respuesta de la API expone una clave de proveedor

## 8. Importación de datos existentes

- [x] 8.1 Trasladar al servidor la lectura del respaldo ZIP reutilizando la
      lógica de `backup_bundle.dart` y `transfer_service.dart`
- [x] 8.2 Rechazar respaldos que declaren una versión de formato futura, sin
      alterar los datos de la cuenta
- [x] 8.3 Extraer los retratos, almacenarlos como blobs de la cuenta y reescribir
      las referencias del personaje a claves
- [x] 8.4 Importar personajes con esquema histórico migrándolos a la versión
      vigente
- [x] 8.5 Aplicar toda la importación en una única transacción
- [x] 8.6 Asignar identificadores libres ante colisión, sin sobrescribir
      personajes existentes
- [x] 8.7 Probar el rechazo de una entrada cuya ruta intente escapar del espacio
      de destino
- [x] 8.8 Probar que importar el mismo respaldo dos veces no corrompe ni elimina
      lo anterior
- [x] 8.9 Exponer la importación en la interfaz web como subida de archivo
      (subida por `file_picker` en el dashboard, sube el ZIP tal cual a
      `POST /api/import`; sin vista previa del contenido porque el cliente ya
      no decodifica el ZIP, ver 9.2)

## 9. Cliente web

- [x] 9.1 Habilitar el objetivo web de `dnd_app` y comprobar que compila con el
      motor ya desbloqueado
- [x] 9.1b Exponer `/api/characters`, `/api/homebrew` y `/api/settings` en
      `dnd_server` (GET/POST/PUT/DELETE sobre los repositorios de la sección 4,
      que hasta ahora no tenían ruta HTTP propia — hueco descubierto al
      empezar 9.2, sin el cual el cliente no tiene qué llamar)
- [x] 9.2 Implementar el cliente de API que reemplaza a `lib/data/`
      (`lib/api/api_client.dart`; `lib/data/` se reescribió en vez de
      portarse, per D6 — `character_store.dart`, `app_paths.dart`,
      `atomic_json_file.dart`, `data_recovery.dart`, `update_service.dart` y
      `creation_draft_store.dart` se eliminaron por no tener sentido sin
      disco local. `lib/ai/` se recortó a `portrait_prompt.dart`: la
      generación y sus proveedores concretos ya viven solo en `dnd_server`)
- [x] 9.3 Reemplazar el arranque de `main.dart` para obtener contenido oficial y
      homebrew de la cuenta autenticada
- [x] 9.4 Retirar del build web la comprobación de actualizaciones, la apertura
      de la carpeta de exportaciones y el listado de respaldos del disco
- [x] 9.5 Entregar exportaciones y respaldos como descarga del navegador
      (`lib/web/browser.dart`; el ZIP se sigue armando en el cliente con
      `BackupBundleCodec.encode`, ahora leyendo los retratos vía
      `GET /api/portraits/<key>` en lugar de disco — el servidor sigue sin
      producir ZIPs, ver `dnd_server/lib/src/import/backup_bundle.dart`)
- [x] 9.6 Implementar la redirección a autenticación cuando no hay sesión válida
- [x] 9.7 Manejar la expiración de sesión durante el uso sin descartar cambios
      pendientes de envío
- [x] 9.8 Mostrar de forma visible los fallos de guardado y no presentar como
      guardado lo que el servidor no confirmó
- [x] 9.9 Distinguir "sin conexión" de "cuenta sin personajes" al cargar
- [x] 9.10 Implementar el buffer local del estado de combate con envío periódico
      (el debounce de 400 ms + cola de guardado serializada por personaje que
      ya tenía `CharactersController` cumple este contrato tal cual: refleja
      el cambio en memoria al instante y envía a la API con demora corta;
      falta medir en juego real si 400 ms alcanza, que es trabajo de ajuste
      posterior, no de esta tarea)
- [ ] 9.11 Verificar la usabilidad en tableta horizontal en ficha, combate y
      creación (revisión de código hecha — breakpoints ya presentes en
      dashboard/ficha/wizard; falta la comprobación visual real, no cubierta
      por tests)
- [ ] 9.12 Comprobar la paridad de la ficha compilada contra el mismo personaje
      en la aplicación de escritorio (garantizado por construcción: el cliente
      web no duplica `CharacterCompiler` ni ningún cálculo de reglas, usa el
      mismo `dnd_engine` sin modificar — esta sesión no tocó el motor. Falta
      la comprobación visual lado a lado con el build de escritorio, que no
      corrió en este entorno)

## 10. Despliegue autoalojado

- [x] 10.1 Escribir la composición de contenedores: API, PostgreSQL de la
      aplicación, Zitadel con su base, volumen de retratos y `cloudflared`
      (`docker-compose.yml`; `packages/dnd_server/Dockerfile` arma la imagen
      única que sirve API + cliente web, ver 9.1b/D5. Zitadel v4 exige un
      segundo contenedor propio para la UI de login (`zitadel-login`), que no
      estaba en el enunciado original de esta tarea pero es indispensable
      para que el login funcione con la versión actual — se agregó junto con
      `zitadel`, verificado contra el `docker-compose.yml` oficial de
      Zitadel)
- [x] 10.2 Versionar un archivo de configuración de ejemplo con marcadores, sin
      secretos reales (`.env.example` y `cloudflared/config.example.yml`)
- [x] 10.3 Hacer que la API espere a que la base esté disponible en lugar de
      terminar en fallo permanente (ya implementado en `bin/server.dart`,
      `_runMigrationsWithRetry`, antes de esta sesión — sin cambios)
- [x] 10.4 Añadir comprobaciones de salud a cada servicio (`db`, `zitadel`,
      `zitadel-login`, `server` y `cloudflared` tienen `healthcheck` en
      `docker-compose.yml`; `server` reutiliza `/health`, que ya existía.
      `zitadel-db` tenía la suya propia hasta que 10.11 unificó las dos
      instancias)
- [x] 10.5 Configurar los dos nombres públicos del túnel y hacer coincidir el
      dominio externo de Zitadel con el del emisor
      (`cloudflared/config.example.yml` mapea `fichas.*` a `server` y
      `auth.*` a `zitadel`/`zitadel-login`; `.env.example` documenta que
      `ZITADEL_EXTERNAL_DOMAIN` debe ser ese mismo hostname)
- [x] 10.6 Configurar la caché de borde para que `index.html` y el *service
      worker* no sobrevivan a un despliegue, y los recursos con huella sí
      (`lib/src/web/cache_headers.dart`, con pruebas propias; sin un
      contenedor de proxy dedicado, es el propio `dnd_server` quien sirve el
      build web con estos encabezados, ver 9.1/D6)
- [ ] 10.7 Verificar que la base de datos y el almacenamiento de blobs no son
      alcanzables desde internet (revisado por diseño: ningún servicio de
      `docker-compose.yml` publica `ports:`, solo `cloudflared` sale a
      internet; el procedimiento de verificación en caliente está en
      `docs/despliegue.md`, pero no se ejecutó — este entorno no tiene
      Docker)
- [ ] 10.8 Verificar que ninguna imagen construida contiene credenciales
      (revisado por lectura: el `Dockerfile` no recibe secretos por `ARG` ni
      los `COPY`, la configuración se lee de entorno recién al arrancar; el
      comando `docker history` para confirmarlo está en
      `docs/despliegue.md`, no se corrió — sin Docker en este entorno)
- [ ] 10.9 Documentar y probar el respaldo y la restauración de todo el estado
      persistente en una instalación limpia (documentado en
      `docs/despliegue.md` con un `pg_dumpall`/`tar` desde que 10.11 unificó
      las dos bases en una instancia; la prueba real contra una instalación
      limpia queda pendiente, sin Docker acá)
- [ ] 10.10 Probar un arranque desde cero: levantar, iniciar sesión y crear un
      personaje (checklist escrito en `docs/despliegue.md`, "Arranque desde
      cero"; no ejecutado en este entorno, que no tiene Docker ni un dominio
      real detrás de Cloudflare)
- [x] 10.11 Unificar las dos instancias de PostgreSQL en una sola con dos bases
      (D11): `postgres-init/init-zitadel-db.sh`, montado en
      `/docker-entrypoint-initdb.d/`, crea el rol y la base `zitadel` y
      revoca `CONNECT` de `PUBLIC` en las dos bases; DSN de Zitadel apunta a
      `db`; `zitadel-db-data` y el servicio `zitadel-db` se eliminaron;
      `.env.example` y `docs/despliegue.md` actualizados (respaldo con un
      solo `pg_dumpall`). Hecho antes de 5.1, sin datos que migrar. El
      aislamiento resultante es asimétrico — ver design.md, decisión D11 y
      Risks/Trade-offs — porque `$APP_DB_USER` es superusuario de la
      instancia (comportamiento de la imagen oficial de postgres, no algo
      configurado acá) y por lo tanto no queda bloqueado por el `REVOKE
      CONNECT` de la base de Zitadel; solo el sentido inverso queda
      garantizado. No se ejecutó contra Docker real, ver 10.12
- [ ] 10.12 Verificar en el arranque desde cero (D11) que `start-from-init` de
      Zitadel funciona con el rol y la base pre-creados por
      `postgres-init/init-zitadel-db.sh`, y confirmar la asimetría del
      aislamiento documentada en 10.11: el rol `zitadel` NO puede conectarse
      a la base de la aplicación; el rol de la aplicación SÍ puede conectarse
      a la base de Zitadel (checklist en `docs/despliegue.md`, "Arranque
      desde cero", pasos 6)

## 11. Cierre

- [ ] 11.1 Migrar los datos propios de `FichasDnD` como primer caso real
      (bloqueada: requiere un servidor desplegado de verdad —Zitadel con la
      aplicación cliente registrada, dominio público— que no existe en este
      entorno de trabajo. El camino queda documentado en
      `docs/despliegue.md`: exportar el ZIP desde la app de escritorio y
      subirlo por `POST /api/import`, ver 8.9)
- [x] 11.2 Actualizar `CLAUDE.md`: el producto deja de ser offline-first, Windows
      queda congelado, existe un tercer paquete y cambian los comandos
- [x] 11.3 Actualizar el README con la arquitectura, el despliegue y la ruta de
      migración desde el escritorio
- [x] 11.4 Ejecutar formato, análisis y pruebas de los tres paquetes
      (`dnd_engine`: 501 pruebas; `dnd_app`: analyze e formato limpios tras
      corregir 8 archivos sin formatear y silenciar dos lints esperables de
      `browser_web.dart` con `ignore_for_file`, ver ese archivo; `dnd_server`:
      145 pruebas)
- [x] 11.5 Revisar el aislamiento entre cuentas como comprobación de seguridad
      previa a publicar el dominio (inventario de la cobertura existente:
      sesión, ajustes, retratos y homebrew ya tenían prueba cruzada; faltaba
      una para escritura de personajes — se agregaron dos pruebas en
      `app_test.dart` que confirman que borrar o actualizar con el id de un
      personaje ajeno nunca toca la fila de la otra cuenta, consistente con
      la clave primaria compuesta `(user_id, id)` de D3)
