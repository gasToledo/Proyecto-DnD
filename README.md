# Fichas D&D 5e

Aplicación de escritorio para crear y usar personajes de **D&D 5.ª edición con las reglas de 2024**.

La app funciona sin cuentas y sin conexión para todo lo relacionado con la ficha. Los personajes se guardan en tu equipo. Solo necesitás internet si querés generar retratos con IA o consultar si hay una versión nueva.

> La versión distribuida actualmente está pensada para **Windows**.

## Descargar e instalar

1. Abrí la página de [últimas versiones publicadas](https://github.com/gasToledo/Proyecto-DnD/releases/latest).
2. Descargá el archivo ZIP que termina en `-windows.zip`.
3. Extraé el ZIP completo en una carpeta de tu elección. No ejecutes el programa directamente desde dentro del ZIP.
4. Abrí `dnd_app.exe`.

Windows puede mostrar una advertencia de SmartScreen porque el ejecutable todavía no tiene firma digital. En ese caso, elegí **Más información → Ejecutar de todas formas**.

Si la aplicación no inicia, instalá el [Microsoft Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe) y volvé a abrirla.

La aplicación no necesita un instalador: la carpeta extraída contiene todo lo necesario. Para desinstalarla, cerrala y eliminá esa carpeta. Tus personajes se guardan en otra ubicación y no se eliminan al quitar el programa.

## Qué podés hacer

### Crear personajes

El asistente te guía paso a paso para elegir:

- especie, linaje, clase y trasfondo;
- puntuaciones de características mediante tiradas o array estándar;
- equipo inicial, armas y armadura;
- aptitudes, dotes, maestrías y conjuros cuando corresponda;
- nombre y datos finales del personaje.

El borrador se guarda mientras avanzás. Si cerrás el asistente, podés retomarlo después, y la aplicación pide confirmación antes de descartar elecciones sin terminar.

La app incluye las opciones disponibles del catálogo 2024, la clase Artífice y contenido de *Forge of the Artificer*. Cada opción muestra su procedencia para que sepas qué material está usando tu mesa.

### Consultar y usar la ficha

Desde el dashboard podés ver todos tus personajes, buscarlos, abrirlos, renombrarlos, archivarlos o marcarlos como muertos sin perder sus datos.

La ficha está dividida en secciones para encontrar rápido lo que necesitás durante una partida:

- **Personaje:** características, habilidades, salvaciones, rasgos y datos generales.
- **Combate:** puntos de golpe, daño, curación, puntos de golpe temporales, condiciones, salvaciones contra muerte, concentración y recursos.
- **Inventario:** armas, armaduras, equipo, ataques y maestrías.
- **Conjuros:** conjuros conocidos o preparados, espacios disponibles y conjuros concedidos por rasgos.
- **Notas:** información libre del personaje o de la partida.

Los valores derivados —como clase de armadura, modificadores, ataques, daño, velocidad y espacios de conjuro— se calculan automáticamente a partir de tus elecciones.

### Llevar el combate

Durante la partida podés registrar daño, curación, descansos, recursos gastados, condiciones, concentración, conjuros lanzados y salvaciones contra muerte. También podés elegir qué arma está en cada mano y cambiar el equipo usado.

Los cambios se guardan automáticamente con un pequeño retraso para no perder información mientras jugás. Todo este módulo funciona offline.

### Subir de nivel

La subida de nivel se inicia manualmente desde la ficha. Un asistente muestra únicamente los pasos que corresponden al nuevo nivel, por ejemplo:

- elegir puntos de golpe tirando el dado o usando el valor promedio;
- elegir subclase cuando corresponda;
- mejorar características o elegir una dote;
- resolver elecciones de clase, maestrías o invocaciones;
- actualizar conjuros y espacios;
- revisar un resumen de todos los cambios antes de confirmarlos.

### Crear contenido propio

La sección **Homebrew** permite agregar contenido personalizado para tu mesa:

- armas y armaduras;
- dotes;
- especies;
- trasfondos;
- conjuros.

El contenido propio se mezcla con el catálogo oficial, pero queda identificado por separado. También podés exportarlo e importarlo en otra instalación.

### Generar o importar retratos

Desde la ficha podés:

- generar retratos a partir de los datos del personaje;
- agregar una descripción, estilo o imagen de referencia;
- elegir entre Pollinations, Azure AI Foundry o Azure `gpt-image-2`;
- importar una imagen desde tu equipo;
- guardar las imágenes elegidas junto al personaje.

Pollinations no requiere API key. Los proveedores de Azure requieren que configures tu propia clave en **Ajustes**.

La generación de retratos necesita conexión y envía la descripción o imagen de referencia al proveedor que elijas. La ficha y el resto de la aplicación siguen funcionando sin internet.

### Exportar, importar y respaldar

Desde el dashboard podés exportar un personaje individual o crear un respaldo completo de la aplicación.

Un respaldo completo puede incluir:

- personajes;
- retratos guardados;
- contenido Homebrew;
- preferencias de la aplicación.

Las claves de servicios de imágenes nunca se incluyen en los respaldos. Al importar, la app muestra una vista previa y evita sobrescribir personajes existentes sin avisarte.

### Actualizaciones

Al iniciar, la aplicación consulta en segundo plano si existe una versión nueva. Si la encuentra, te ofrece descargar el ZIP en la carpeta de exportaciones.

La actualización actual es manual: descargás el ZIP, lo extraés y abrís la nueva versión. La aplicación no reemplaza sus propios archivos mientras está abierta.

## Datos, privacidad y recuperación

No hay servidor ni base de datos online. Los datos se guardan localmente en:

```text
<perfil>/FichasDnD/
  characters/       personajes
  homebrew/         contenido propio
  portraits/        retratos
  exports/          archivos exportados y respaldos
  recovery/         archivos apartados para recuperación
  settings.json     preferencias locales
```

Los personajes se escriben de forma atómica para reducir el riesgo de corrupción. La aplicación conserva copias antes de migrar datos antiguos y no sobrescribe documentos creados por una versión futura.

## Limitaciones actuales

- Cada personaje usa una sola clase; todavía no hay multiclase.
- No hay sincronización en la nube.
- No hay Modo DM para administrar personajes o criaturas de una partida.
- Algunas reglas avanzadas todavía se muestran como información, pero no tienen automatización completa: objetos mágicos, compañeros con estadísticas propias, compra de puntos, precio y peso detallados del equipo, entre otras.
- La validación avisa sobre inconsistencias, pero no bloquea las decisiones: el DM conserva la última palabra.

## Mejoras previstas

El proyecto tiene previstas, entre otras, estas mejoras:

- instalador de Windows firmado y actualización automática segura;
- automatización completa de build, publicación y verificación de versiones;
- compra de puntos y más reglas de equipo;
- efectos mecánicos para objetos mágicos, compañeros y reglas avanzadas pendientes;
- soporte para multiclase;
- sincronización entre dispositivos;
- Modo DM para gestionar personajes, NPC y referencias de la mesa.

## Compilar desde el código

Para trabajar con el repositorio necesitás Dart, Flutter y las herramientas de compilación de Windows.

Motor de reglas:

```sh
cd packages/dnd_engine
dart pub get
dart analyze
dart test
```

Aplicación:

```sh
cd packages/dnd_app
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

La guía técnica para contribuir está en [CLAUDE.md](CLAUDE.md). El detalle del avance y las verificaciones de reglas está en [docs/auditoria-reglas-2024.md](docs/auditoria-reglas-2024.md).

## Reglas y licencia

El proyecto utiliza como referencia de reglas el material de 2024 y contiene material del [SRD 5.2.1](https://www.dndbeyond.com/srd), publicado bajo [Creative Commons BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode).

El catálogo también puede incluir contenido del PHB 2024 y de *Forge of the Artificer* que no forma parte del SRD. La aplicación identifica la procedencia de cada opción y ese contenido no se presenta como material cubierto por la licencia del SRD.
