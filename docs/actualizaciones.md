# Actualizaciones de la aplicación

> Este documento describe `update_service.dart`, que existió en la aplicación
> de escritorio de Windows. Esa aplicación quedó **congelada** con la
> migración a webapp autoalojada (ver `CLAUDE.md` y
> `openspec/changes/migrate-to-self-hosted-webapp/`) y el servicio se retiró
> del cliente web: el despliegue *es* la actualización, no hay nada que
> comprobar. Se conserva como referencia histórica de cómo funcionaba el
> último release de escritorio publicado.

## Alcance actual

Al abrir el dashboard, la aplicación consulta en segundo plano el último Release
estable de GitHub. Si el tag publicado es posterior a la versión instalada,
muestra las notas y pregunta si el usuario quiere descargar el ZIP para Windows.

La descarga se guarda en `<perfil>/FichasDnD/exports/`. La comprobación no
bloquea el inicio: sin conexión o ante un error de GitHub, la aplicación sigue
funcionando normalmente y no muestra un error.

Para que la comparación sea correcta, cada publicación debe cumplir estas reglas:

1. `pubspec.yaml` declara la misma versión que el tag, sin contar el prefijo `v`
   ni el número de compilación. Ejemplo: `0.4.1+1` corresponde a `v0.4.1`.
2. El Release no es borrador ni prerelease.
3. Incluye un asset cuyo nombre termina en `-windows.zip`.

## Mejora futura: instalar y reiniciar

El ZIP portable no puede reemplazar de forma segura el ejecutable mientras la
aplicación está abierta. Para ofrecer **Actualizar y reiniciar**, el camino
recomendado es:

1. Generar un instalador de Windows firmado, por ejemplo con Inno Setup.
2. Publicar el instalador y su suma SHA-256 como assets del Release.
3. Hacer que la aplicación descargue y verifique ambos archivos.
4. Ejecutar el instalador en modo de actualización y cerrar la aplicación.
5. Dejar que el instalador reemplace los binarios, conserve `FichasDnD/` y abra
   la nueva versión al terminar.
6. Automatizar build, pruebas, versión, firma y publicación mediante GitHub
   Actions para evitar diferencias entre `pubspec.yaml`, el tag y el binario.

Hasta incorporar un instalador firmado, la aplicación solo descarga el ZIP y
abre su carpeta; no modifica su propia instalación.
