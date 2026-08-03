## 1. Desbloquear la compilación web

- [ ] 1.1 Sacar `loadFromDirectory` de la ruta importable por web en
      `dnd_engine` (hoy `lib/dnd_engine.dart` exporta `content_repository.dart`,
      que importa `dart:io`), conservando el punto de entrada para pruebas
- [ ] 1.2 Verificar que las 47 llamadas a `loadFromDirectory` de las pruebas de
      ambos paquetes siguen pasando sin cambios de comportamiento
- [ ] 1.3 Añadir una prueba o comprobación de compilación que falle si `dart:io`
      vuelve a entrar en la superficie web del motor
- [ ] 1.4 Confirmar con una compilación web mínima que el motor ya compila para
      navegador

## 2. Retratos como claves opacas en el dominio

- [ ] 2.1 Redefinir `Character.portraitPaths` como claves opacas de retrato y
      actualizar su documentación en `character.dart`
- [ ] 2.2 Escribir la prueba de regresión que falla al leer un personaje
      histórico con rutas absolutas, antes de implementar la migración
- [ ] 2.3 Implementar la migración de esquema versionada de rutas a claves y
      subir `currentSchemaVersion`
- [ ] 2.4 Reemplazar los tres renderizados atados al disco
      (`dashboard_widgets.dart:235`, `sheet_navigation.dart:55`,
      `sheet_widgets.dart:40`) por un único widget que resuelva la clave
- [ ] 2.5 Verificar que un personaje exportado ya no contiene ninguna ruta del
      sistema de archivos

## 3. Paquete del servidor

- [ ] 3.1 Crear `packages/dnd_server` como paquete Dart con `dnd_engine` como
      dependencia de ruta
- [ ] 3.2 Establecer el esqueleto HTTP con enrutado, manejo de errores y
      apagado ordenado
- [ ] 3.3 Exponer el punto de comprobación de salud del servicio
- [ ] 3.4 Añadir los comandos de formato, análisis y pruebas del paquete al
      README y a `CLAUDE.md`
- [ ] 3.5 Definir la carga de configuración por entorno, sin valores por defecto
      que contengan secretos

## 4. Persistencia en PostgreSQL

- [ ] 4.1 Definir el esquema con el documento en `jsonb`, columnas generadas y
      clave primaria compuesta `(user_id, id)`
- [ ] 4.2 Establecer el mecanismo de migraciones de base de datos y su ejecución
      al arrancar
- [ ] 4.3 Implementar el repositorio de personajes: alta, lectura, listado,
      actualización y baja, con propiedad por cuenta
- [ ] 4.4 Aplicar la migración secuencial de documentos históricos al leer, y el
      rechazo sin escritura de versiones futuras
- [ ] 4.5 Implementar la escritura multi-documento en una única transacción
- [ ] 4.6 Implementar los repositorios de homebrew y de ajustes por cuenta
- [ ] 4.7 Implementar la asignación de un identificador libre cuando el
      solicitado ya existe en la cuenta
- [ ] 4.8 Probar que un fallo a mitad de una escritura por lotes no deja
      documentos modificados
- [ ] 4.9 Probar que el estado de combate sobrevive a ediciones de equipo,
      conjuros y nivel

## 5. Autenticación y aislamiento de cuentas

- [ ] 5.1 Levantar Zitadel con su propia base y registrar la aplicación cliente
- [ ] 5.2 Implementar el flujo Authorization Code con PKCE del lado del servidor
- [ ] 5.3 Emitir la sesión como cookie `httpOnly`, `Secure` y `SameSite`, y
      conservar los tokens solo en el servidor
- [ ] 5.4 Implementar el cierre de sesión y la invalidación de la sesión de
      servidor
- [ ] 5.5 Mapear el sujeto OIDC verificado a una fila de usuario propia
- [ ] 5.6 Aplicar el filtro de propiedad a toda lectura y escritura de datos
- [ ] 5.7 Escribir las pruebas de acceso cruzado: una cuenta que conoce el
      identificador de otra no obtiene el recurso ni confirmación de que existe
- [ ] 5.8 Probar que una aserción con emisor o firma inválidos se rechaza
- [ ] 5.9 Verificar que tras iniciar sesión no hay tokens del proveedor en el
      almacenamiento del navegador

## 6. Almacenamiento y servido de retratos

- [ ] 6.1 Definir la interfaz de almacenamiento de blobs de retrato
- [ ] 6.2 Implementarla sobre volumen de disco, trasladando
      `portrait_storage.dart` al servidor
- [ ] 6.3 Exponer el servido de retratos del mismo origen, autorizado por la
      sesión
- [ ] 6.4 Validar tipo y tamaño de las imágenes entrantes contra el límite
      configurado
- [ ] 6.5 Rechazar claves de retrato que intenten salir del espacio de la cuenta
- [ ] 6.6 Probar que un retrato ajeno responde como inexistente y que uno sin
      sesión no se entrega
- [ ] 6.7 Probar que los retratos sobreviven al reinicio de los contenedores

## 7. Generación de retratos con IA en el servidor

- [ ] 7.1 Trasladar `lib/ai/` de `dnd_app` a `dnd_server` conservando la
      inyección de cliente HTTP que ya tienen los servicios
- [ ] 7.2 Cargar las credenciales de proveedor desde la configuración del
      servidor
- [ ] 7.3 Exponer el punto de generación de la API propia, incluida la variante
      con imagen de referencia
- [ ] 7.4 Ocultar como seleccionable todo proveedor sin credenciales
      configuradas
- [ ] 7.5 Degradar al proveedor predeterminado ante un proveedor retirado o
      desconocido, conservando el resto de los ajustes
- [ ] 7.6 Descartar respuestas ilegibles o fallidas sin dejar un retrato parcial
      asociado
- [ ] 7.7 Implementar la subida de un retrato propio, disponible aunque no haya
      proveedores configurados
- [ ] 7.8 Verificar que ninguna respuesta de la API expone una clave de proveedor

## 8. Importación de datos existentes

- [ ] 8.1 Trasladar al servidor la lectura del respaldo ZIP reutilizando la
      lógica de `backup_bundle.dart` y `transfer_service.dart`
- [ ] 8.2 Rechazar respaldos que declaren una versión de formato futura, sin
      alterar los datos de la cuenta
- [ ] 8.3 Extraer los retratos, almacenarlos como blobs de la cuenta y reescribir
      las referencias del personaje a claves
- [ ] 8.4 Importar personajes con esquema histórico migrándolos a la versión
      vigente
- [ ] 8.5 Aplicar toda la importación en una única transacción
- [ ] 8.6 Asignar identificadores libres ante colisión, sin sobrescribir
      personajes existentes
- [ ] 8.7 Probar el rechazo de una entrada cuya ruta intente escapar del espacio
      de destino
- [ ] 8.8 Probar que importar el mismo respaldo dos veces no corrompe ni elimina
      lo anterior
- [ ] 8.9 Exponer la importación en la interfaz web como subida de archivo

## 9. Cliente web

- [ ] 9.1 Habilitar el objetivo web de `dnd_app` y comprobar que compila con el
      motor ya desbloqueado
- [ ] 9.2 Implementar el cliente de API que reemplaza a `lib/data/`
- [ ] 9.3 Reemplazar el arranque de `main.dart` para obtener contenido oficial y
      homebrew de la cuenta autenticada
- [ ] 9.4 Retirar del build web la comprobación de actualizaciones, la apertura
      de la carpeta de exportaciones y el listado de respaldos del disco
- [ ] 9.5 Entregar exportaciones y respaldos como descarga del navegador
- [ ] 9.6 Implementar la redirección a autenticación cuando no hay sesión válida
- [ ] 9.7 Manejar la expiración de sesión durante el uso sin descartar cambios
      pendientes de envío
- [ ] 9.8 Mostrar de forma visible los fallos de guardado y no presentar como
      guardado lo que el servidor no confirmó
- [ ] 9.9 Distinguir "sin conexión" de "cuenta sin personajes" al cargar
- [ ] 9.10 Implementar el buffer local del estado de combate con envío periódico
- [ ] 9.11 Verificar la usabilidad en tableta horizontal en ficha, combate y
      creación
- [ ] 9.12 Comprobar la paridad de la ficha compilada contra el mismo personaje
      en la aplicación de escritorio

## 10. Despliegue autoalojado

- [ ] 10.1 Escribir la composición de contenedores: API, PostgreSQL de la
      aplicación, Zitadel con su base, volumen de retratos y `cloudflared`
- [ ] 10.2 Versionar un archivo de configuración de ejemplo con marcadores, sin
      secretos reales
- [ ] 10.3 Hacer que la API espere a que la base esté disponible en lugar de
      terminar en fallo permanente
- [ ] 10.4 Añadir comprobaciones de salud a cada servicio
- [ ] 10.5 Configurar los dos nombres públicos del túnel y hacer coincidir el
      dominio externo de Zitadel con el del emisor
- [ ] 10.6 Configurar la caché de borde para que `index.html` y el *service
      worker* no sobrevivan a un despliegue, y los recursos con huella sí
- [ ] 10.7 Verificar que la base de datos y el almacenamiento de blobs no son
      alcanzables desde internet
- [ ] 10.8 Verificar que ninguna imagen construida contiene credenciales
- [ ] 10.9 Documentar y probar el respaldo y la restauración de todo el estado
      persistente en una instalación limpia
- [ ] 10.10 Probar un arranque desde cero: levantar, iniciar sesión y crear un
      personaje

## 11. Cierre

- [ ] 11.1 Migrar los datos propios de `FichasDnD` como primer caso real
- [ ] 11.2 Actualizar `CLAUDE.md`: el producto deja de ser offline-first, Windows
      queda congelado, existe un tercer paquete y cambian los comandos
- [ ] 11.3 Actualizar el README con la arquitectura, el despliegue y la ruta de
      migración desde el escritorio
- [ ] 11.4 Ejecutar formato, análisis y pruebas de los tres paquetes
- [ ] 11.5 Revisar el aislamiento entre cuentas como comprobación de seguridad
      previa a publicar el dominio
