# Guía de Diseño Web — Milantus, Asistente de Aventuras

Sistema de diseño del cliente web de **Milantus**. Documenta la tecnología, la
composición de la interfaz, la paleta, la tipografía, la forma y el
comportamiento tal como están **implementados hoy** en
`packages/dnd_app/lib/`, no como aspiración.

> **Regla de oro de este documento**: cada valor de acá sale del código. Si el
> código y esta guía discrepan, gana el código y la guía se corrige. Los
> archivos fuente de cada sección están citados para que se pueda verificar.

## Cómo usar esta guía

**Si sos una persona diseñando o revisando pantallas**: leé
[Dirección de arte](#2-dirección-de-arte), [Color](#3-color),
[Tipografía](#4-tipografía) y el
[Catálogo de componentes](#8-catálogo-de-componentes). El resto es referencia.

**Si sos un modelo de IA generando propuestas de diseño o código de UI**:

1. Los tokens legibles por máquina están en el
   [Apéndice A](#apéndice-a--tokens-en-json) (JSON) y el
   [Apéndice B](#apéndice-b--equivalencia-en-css) (CSS custom properties).
   Usá esos valores literales; no inventes intermedios ni "aproximaciones de
   marca".
2. Las prohibiciones duras están en [Anti-patrones](#12-anti-patrones). Son
   restricciones de arquitectura, no preferencias estéticas: violarlas rompe
   pruebas o el build.
3. El destino real es **Flutter/Dart**, no HTML/CSS. Si producís un mockup en
   HTML, marcá explícitamente que es un mockup y traducí los tokens a los
   nombres Dart de la tabla de [Color](#3-color).

### Flujo de diseño e implementación

La web desplegada es la única superficie real de validación visual. Por eso el
proceso completo para un cambio visible es:

1. Leer la pantalla, los componentes compartidos y las pruebas afectadas antes
   de proponer el cambio.
2. Contrastar la propuesta con Dirección de arte, Color, Tipografía, Layout,
   Accesibilidad y Anti-patrones de esta guía; reutilizar componentes y tokens
   existentes antes de crear otros.
3. Mantener las reglas de D&D en `dnd_engine`. La UI recibe resultados de
   `ComputedSheet` y se limita a presentación y orquestación.
4. Implementar la pantalla en Flutter contemplando tema oscuro y claro, estado
   vacío, texto largo y los anchos definidos en Layout y responsividad.
5. Agregar pruebas de regresión del comportamiento y de la interacción visible.
6. Formatear, analizar, ejecutar las suites afectadas y generar
   `flutter build web --release` antes del commit.
7. Commitear y pushear directamente a `main`, el único tronco activo. El push
   ejecuta CI y, cuando toca rutas desplegables, CD.
8. Seguir ambas ejecuciones hasta el final y comprobar manualmente el cambio en
   la web desplegada. Un build local exitoso no sustituye esta revisión visual.

---

## 1. Stack tecnológico del frontend

| Capa | Tecnología | Detalle |
| --- | --- | --- |
| Framework de UI | **Flutter** (canal estable, SDK Dart `^3.12.0`) | `packages/dnd_app/pubspec.yaml` |
| Plataforma objetivo | **Web** (`flutter build web --release`) | Única plataforma mantenida activamente |
| Lenguaje | **Dart** | Nada de JS/TS de aplicación: no hay capa web propia salvo `lib/web/` |
| Sistema de diseño base | **Material 3** (`useMaterial3: true`) | Con `ColorScheme` y `ThemeExtension` propios |
| Renderizado | Motor web de Flutter (CanvasKit / skwasm según build) | El DOM no es una superficie de estilado: **no hay CSS de aplicación** |
| Shell HTML | `web/index.html` + `web/manifest.json` | Solo metadatos, favicon, PWA e iconos |
| Estado | `StatefulWidget` + controladores propios (`CharactersController`) | Sin Redux/Bloc/Riverpod ni ninguna dependencia de estado |
| Red | `package:http` contra el mismo origen | `lib/api/api_client.dart`, `baseUrl` vacío, cookie de sesión `httpOnly` |
| Reglas de negocio | `packages/dnd_engine` (Dart puro) | **La UI nunca recalcula reglas** |

**Consecuencia de diseño más importante del stack**: la aplicación se dibuja
sobre un lienzo, no sobre el DOM. No existen hojas de estilo, clases CSS,
selectores ni cascada. Todo el estilado es **léxico**, vía `ThemeData` y widgets.
Un cambio "global" de apariencia se hace en `lib/theme/app_theme.dart` o no se
hace.

### Dependencias que afectan la interfaz

`file_picker` (importar retrato), `archive` (respaldo ZIP),
`package_info_plus` (versión en el pie del panel). Nada más. **Sumar un plugin
nativo es una decisión de arquitectura, no de diseño**: obliga a que toda
máquina que compile tenga el Modo Desarrollador de Windows activo.

---

## 2. Dirección de arte

**Híbrido: base oscura moderna + heráldica de fantasía.**

La aplicación es una herramienta de mesa que se usa durante horas, muchas veces
en penumbra. La lectura manda sobre la ambientación. La fantasía entra por
**acento y ornamento discreto** —oro heráldico, siluetas de escudo, un rombo
como separador— nunca por textura, ruido, pergamino simulado ni tipografías
góticas.

Los cuatro compromisos que definen el estilo:

1. **El oscuro es el tema prioritario y el que arranca.** El claro existe y es
   completo, pero es la variante. `ThemeMode.dark` es el estado inicial en
   `main.dart`.
2. **Superficies planas, jerarquía por borde.** `Card` tiene `elevation: 0`. La
   profundidad se comunica con una línea de 1 px (`hairline`) y con un fondo
   más hundido (`plaque`), no con sombras. La única sombra del sistema es la de
   *hover* de la tarjeta de personaje.
3. **El oro es información, no decoración.** Marca lo activo, lo seleccionado y
   los números clave (CA, características, recursos). Si algo está en oro y no
   es ninguna de esas tres cosas, está mal.
4. **Densidad alta, tipografía tranquila.** Una ficha de D&D es una tabla de
   números. Se privilegia ver mucho de un vistazo antes que respirar.

### Vocabulario visual propietario

Tres formas son marca registrada del producto y hay que reusarlas en vez de
inventar equivalentes:

- **El rombo** (cuadrado rotado 45°, `angle: 0.785398`): logotipo en la cabecera
  del panel y centro de `SectionRule`.
- **El escudo**: silueta recortada con `_ShieldClipper` que contiene la Clase de
  Armadura, y solo la CA.
- **El medallón**: círculo con aro dorado de 2 px para retratos y emblemas.

---

## 3. Color

Fuente: `lib/theme/app_theme.dart`. Los tokens propios viven en `AppPalette`,
un `ThemeExtension`, y se leen con `context.palette`. Los tokens estándar viven
en el `ColorScheme` de Material y se leen con `Theme.of(context).colorScheme`.

### 3.1 Tokens propios — `AppPalette`

| Token | Oscuro | Claro | Qué significa |
| --- | --- | --- | --- |
| `gold` | `#C9A24B` | `#8A6A1E` | Acento heráldico: activo, seleccionado, números clave, reglas ornamentales |
| `crimson` | `#C24A3E` | `#A6392E` | Puntos de golpe, daño y acción destructiva |
| `plaque` | `#12100C` | `#EBE0C9` | Fondo de placas: **más hundido** que `surface` |
| `hairline` | `#3A2F25` | `#D9C9A8` | Bordes finos de 1 px; toda la jerarquía estructural |
| `goldSoft` | `#2E2617` | `#EEE1BF` | Relleno suave de pills doradas y del ítem de navegación activo |
| `textMuted` | `#7F7059` | `#9E8E70` | Rótulos, eyebrows, hints, pips vacíos |

### 3.2 Tokens de Material — `ColorScheme`

| Rol | Oscuro | Claro | Uso |
| --- | --- | --- | --- |
| `scaffoldBackgroundColor` | `#151210` | `#F3ECDD` | Fondo de página (no es parte del `ColorScheme`) |
| `surface` | `#1E1915` | `#FBF7EC` | Tarjetas, panel lateral, `AppBar` |
| `onSurface` | `#EFE7DA` | `#2A2118` | Texto principal |
| `onSurfaceVariant` | `#A2937E` | `#6E5F49` | Texto secundario |
| `primary` | = `gold` | = `gold` | Acento del sistema |
| `onPrimary` | `#201A10` | `#201A10` | Texto sobre `primary` (ver [nota de accesibilidad](#11-accesibilidad)) |
| `secondary` | = `crimson` | = `crimson` | |
| `error` | = `crimson` | = `crimson` | El error usa el carmesí de la paleta, no un rojo ajeno |
| `outline` | = `hairline` | = `hairline` | |
| `surfaceContainerHighest` | = `plaque` | = `plaque` | |

**Hay tres niveles de fondo y no más**: `scaffold` (página) → `surface`
(tarjeta) → `plaque` (placa dentro de tarjeta). En oscuro `plaque` es *más
oscuro* que `surface`; en claro es *más oscuro* también. La placa siempre se
hunde, nunca se eleva.

### 3.3 Acentos de contenido (colores de clase)

Cada clase declara su `accentColor` **en el JSON del pack**, no en el código:
`packages/dnd_engine/lib/assets/srd_2024/classes.json`. Se parsea con
`classAccent()` (`lib/theme/class_visuals.dart`) y cae a `gold` si falta o es
inválido. Por eso el homebrew accede al mismo mecanismo.

| Clase | Hex | | Clase | Hex |
| --- | --- | --- | --- | --- |
| Guerrero | `#B0413E` | | Brujo | `#7E57C2` |
| Bárbaro | `#C0552B` | | Paladín | `#C8A13A` |
| Pícaro | `#7D6B99` | | Explorador | `#5B8C5A` |
| Monje | `#2E86AB` | | Bardo | `#D98E48` |
| Mago | `#4A6FA5` | | Hechicero | `#C13B5A` |
| Clérigo | `#CBB26A` | | Artífice | `#B08D57` |
| Druida | `#4C8B3F` | | | |

**Alcance del acento de clase**: aro y degradado radial del medallón sin
retrato, y el ícono de clase en la línea "especie · clase" de la tarjeta. No
tiñe fondos, botones ni texto de cuerpo. Una clase no reemplaza el oro del
sistema.

### 3.4 Semántica de estado

| Estado | Tratamiento |
| --- | --- |
| Activo / seleccionado | Texto y/o ícono en `gold`; fondo `goldSoft` si es un ítem de navegación |
| Hover (tarjeta) | Borde `gold` de 1 px + traslación −2 px + sombra `black @ alpha 70`, `blur 26`, `offset (0,10)` |
| Hover (nav) | Fondo `plaque` |
| Favorito | Borde `gold` de **2 px** + estrella dorada junto al nombre |
| Deshabilitado | Comportamiento por defecto de Material (`onSelected: null`) |
| Error | `colorScheme.error` (= `crimson`) + `Icons.error_outline` |
| Éxito | `Colors.green` + `Icons.check_circle_outline` — **única excepción** a la paleta, y solo en `SnackBar` |
| Info | `colorScheme.primary` + `Icons.info_outline` |

**El color nunca es el único portador de significado.** El favorito lleva borde
*y* estrella; el guardado lleva color *y* ícono *y* texto. Es una regla, no una
casualidad: quien no distingue el oro del gris tiene que poder usar la app.

---

## 4. Tipografía

### 4.1 Las dos familias

| Rol | Familia | Declaración |
| --- | --- | --- |
| **Display / títulos / números** | `Georgia` (serif) | Constante `_displayFont` en `app_theme.dart` |
| **Cuerpo / interfaz** | Default de Material (Roboto) | Sin declarar: se hereda del `TextTheme` base |

Georgia no se empaqueta como asset: se pide por nombre y **el navegador cae al
serif genérico del sistema si no está**. Está presente en Windows y macOS; en
Linux y Android típicamente no. Es una decisión consciente (cero peso de fuente
descargada) con una consecuencia real: la ficha se ve distinta en Linux. Ver
[Deuda conocida](#13-deuda-conocida).

**Georgia se usa para exactamente cuatro cosas**: el nombre del personaje, los
títulos de tarjeta y pantalla, los valores de `StatPlaque` / `ShieldBadge`, y la
marca en la cabecera del panel. Todo lo demás es la sans por defecto.

**Un número que se compara con el de al lado va en sans negrita, no en
Georgia.** Es lo que separa a `StatTile` de `StatPlaque`: en la banda táctica de
la ficha, en las plaquetas de característica y en la columna de habilidades, las
cifras se leen en columna y de un vistazo, y el serif —pensado para títulos— las
vuelve más lentas de barrer. Georgia queda para el número que *es* el título de
su caja, que es el caso de las tiras cortas dentro de una tarjeta.

### 4.2 Escala implementada

| Uso | Familia | Tamaño | Otros | Dónde |
| --- | --- | --- | --- | --- |
| Título de `AppBar` | Georgia | 20 | — | `appBarTheme` |
| Marca del panel | Georgia | 18 | `height: 1.25` | `dashboard_navigation.dart` |
| Subtítulo de marca | sans | 11 | `letterSpacing: 0.3`, `gold` | ídem |
| Nombre en tarjeta | Georgia | 18 × escala | — | `dashboard_widgets.dart` |
| Título de `sheetCard` | Georgia | 16 | — | `sheet_navigation.dart` |
| Valor de `StatTile` | sans | 28 | `w700`, `height: 1.05`, cifras tabulares | `app_widgets.dart` |
| Modificador de `AbilityPlaque` | sans | 26 | `w700`, `height: 1`, cifras tabulares | ídem |
| Modificador de habilidad | sans | 16 | `w700`, cifras tabulares | `general_section.dart` |
| Valor de `StatPlaque` | Georgia | 24 (16 en `dense`) | `height: 1`, cifras tabulares | `app_widgets.dart` |
| Valor de `ShieldBadge` | Georgia | 20 × `k` | cifras tabulares | ídem |
| Rótulo de `StatTile` | sans | 11 | `MAYÚSCULAS`, `letterSpacing: 1.1`, `textMuted` | ídem |
| Cuerpo | sans | 14 (default) | — | — |
| Ítem de navegación | sans | 14 | `w600` si activo | `app_widgets.dart` |
| Metadatos de tarjeta | sans | 12.5 × escala | `onSurfaceVariant` | `dashboard_widgets.dart` |
| **Eyebrow** | sans | 11 | `MAYÚSCULAS`, `letterSpacing: 1.6`, `w500`, `textMuted` | `Eyebrow` |
| Texto de pill | sans | 11 | — | `GoldPill` |
| Rótulo de `StatPlaque` | sans | 10 (8.5 en `dense`) | `MAYÚSCULAS`, `letterSpacing: 1.2` (0.5 dense) | `StatPlaque` |
| Rótulo "NIVEL" | sans | 8.5 × escala | `MAYÚSCULAS`, `letterSpacing: 1` | `dashboard_widgets.dart` |

### 4.3 Reglas tipográficas

- **Todo número que se compara en columna lleva `FontFeature.tabularFigures()`.**
  Sin eso, un `18` y un `11` no alinean y la ficha parece temblar al cambiar de
  personaje. Aplica a características, CA, PG, velocidad, iniciativa.
- **Los rótulos van en mayúsculas con `letterSpacing` positivo**, y el
  espaciado crece cuando el tamaño baja (1.6 a 11 px, 1.2 a 10 px, 1 a 8.5 px).
  Nunca mayúsculas sin espaciado.
- **Los modificadores se firman siempre** (`+3`, `−1`), nunca `3`.
- **La escala tipográfica no es modular.** Los tamaños se eligieron por caso.
  No hay ratio; no intentes derivar uno.
- **Los tamaños con `× k` / `× scale` son intencionales**: la tarjeta de
  personaje crece proporcionalmente hasta 1.3× cuando la grilla le da más ancho
  (ver [Layout](#7-layout-y-responsividad)).

---

## 5. Forma, borde y elevación

### 5.1 Radios

| Radio | Aplicación |
| --- | --- |
| `5` | Marca romboidal de la cabecera |
| `8` | Campos de texto (`inputDecorationTheme`) |
| `9` | Ítems de navegación, indicador de guardado, `StatPlaque` densa |
| `12` | **Tarjetas** (`cardTheme`), placas, `DenseRows` |
| `14` | Tarjeta de personaje del dashboard |
| `20` | Pills, chips, cápsula del modificador |
| circular | Medallones, pip de salvación |

El radio por defecto para una superficie nueva es **12**. El 14 de la tarjeta de
personaje es deliberado: esa tarjeta es más grande y más importante.

### 5.2 Bordes

- **1 px de `hairline` es el borde estándar.** Toda tarjeta, placa, pill, chip,
  contenedor de filas y separación de paneles lo usa.
- **2 px de `gold` significa "esto es especial"**: favorito, aro del medallón,
  destino de arrastre.
- Los divisores internos son `Divider(height: 1, color: hairline)` o un
  `Container(height: 1)` — nunca un `Divider` con altura implícita, porque mete
  espacio que no se pidió.

### 5.3 Elevación

`elevation: 0` en tarjetas y `surfaceTintColor: Colors.transparent` en la
`AppBar`: Material 3 tiñe las superficies elevadas con el color primario, y acá
eso metería oro en fondos que deben quedar neutros.

**La única sombra del sistema** es la de hover de la tarjeta de personaje:
`BoxShadow(color: black.withAlpha(70), blurRadius: 26, offset: (0, 10))`.

---

## 6. Espaciado

El espaciado **no sigue una escala estricta de 4** en el código actual; se usan
valores ajustados a ojo por componente (2, 3, 5, 6, 7, 10, 11, 13…).

**Regla para trabajo nuevo**: usar el subconjunto canónico y desviarse solo con
motivo.

| Paso | Uso típico |
| --- | --- |
| `4` | Separación intra-elemento (ícono ↔ texto muy junto) |
| `8` | `spacing` / `runSpacing` de todos los `Wrap` de chips |
| `12` | Padding vertical de placas, separación de bloques cortos |
| `16` | **Espacio entre tarjetas y padding interno de tarjeta** — el valor más común |
| `20` | Padding horizontal de `PageBody`, padding vertical del panel |
| `24` | Padding de estados vacíos y de error |
| `32` | Padding horizontal del dashboard en pantalla ancha; pie de grilla |

Padding de referencia por componente: tarjeta de personaje `16`, cabecera de
`sheetCard` `16 h / 13 v`, ítem de navegación `12 h / 10 v`, `StatPlaque`
`12/11/12/11` (`8/6` densa), pill `9 h / 2 v`.

---

## 7. Layout y responsividad

### 7.1 Anatomía general

```
┌──────────────┬────────────────────────────────────────────┐
│  Panel       │  Contenido                                 │
│  lateral     │  ┌──────────────────────────────────────┐  │
│  236 px      │  │ Barra de acciones (buscar, orden, +) │  │
│              │  ├──────────────────────────────────────┤  │
│  · marca     │  │                                      │  │
│  · nav       │  │   Grilla de tarjetas / cuerpo        │  │
│  · (spacer)  │  │   de la ficha                        │  │
│  · cuenta    │  │                                      │  │
│  · tema      │  └──────────────────────────────────────┘  │
│  · versión   │                                            │
└──────────────┴────────────────────────────────────────────┘
```

El **panel lateral mide 236 px fijos** en las tres pantallas con shell
(dashboard, ficha, wizard de creación). No es flexible: los textos que no
entran se recortan con `ellipsis`.

### 7.2 Breakpoints

| Ancho | Efecto | Constante |
| --- | --- | --- |
| **≥ 900** | Panel lateral fijo. Debajo: `AppBar` + `Drawer` con el **mismo widget** de panel | `_kWideBreakpoint` / `_kSheetWideBreakpoint` |
| ≥ 860 / ≥ 560 | 3 / 2 columnas en secciones de subida de nivel | `level_up_sections.dart` |
| ≥ 780 / ≥ 520 | 3 / 2 columnas en el paso de puntuaciones | `scores_step.dart` |
| ≥ 760 | `PageBody` deja de crecer (`maxWidth: 760`) | `app_widgets.dart` |
| ≥ 640 | La ficha pasa de una columna a columnas lado a lado | `responsiveColumns` |
| < 720 / < 700 / < 600 | Variantes compactas del wizard de subida de nivel | `levelup/` |
| < 560 | Padding horizontal del dashboard baja de 32 a 16 | `dashboard_content.dart` |

**El breakpoint de shell es 900 y es el único que importa recordar.** El resto
son decisiones locales de contenido y se resuelven con `LayoutBuilder`, no con
`MediaQuery`: se mide el espacio *que el padre te dio*, no la ventana.

### 7.3 La grilla del dashboard

```dart
const _kCardBaseWidth  = 420.0;  // diseño de referencia
const _kCardBaseHeight = 212.0;
const _kCardMaxExtent  = 560.0;  // ancho máximo por columna
const _kCardSpacing    =  16.0;
```

`SliverGridDelegateWithMaxCrossAxisExtent` reparte el ancho en columnas de a lo
sumo 560 px. La tarjeta **se escala en proporción** (`scale` entre 1.0 y 1.3)
según el ancho real que le tocó, y el alto de la celda acompaña. Por eso todas
las medidas internas de la tarjeta llevan `× k`.

Consecuencia: **subir `_kCardMaxExtent` no ensancha la tarjeta** si con ese
valor entra una columna más. Los dos parámetros están acoplados.

### 7.4 Reordenamiento

El roster se reordena con `Draggable` + `DragTarget` propios, no con un paquete
de grilla reordenable. El arrastre **arranca con pulsación larga**: la tarjeta
entera ya es un botón, y en pantalla táctil desplazar la grilla no puede
terminar moviendo personajes.

---

## 8. Catálogo de componentes

Todos en `lib/theme/app_widgets.dart` salvo indicación. Son la biblioteca
compartida: **antes de crear un widget visual nuevo, buscar acá**.

### Estructura

| Componente | Qué es | API |
| --- | --- | --- |
| `PageBody` | Cuerpo centrado con ancho máximo (760 por defecto) para que el contenido no se estire de borde a borde | `children`, `maxWidth`, `padding` |
| `DenseRows` | Contenedor de filas densas con divisores internos, en vez de tarjetas sueltas | `children` |
| `SectionRule` | Regla ornamental: línea `hairline` con rombo dorado de 7 px al centro, 18 px de margen vertical | — |
| `Eyebrow` | Rótulo de sección en mayúsculas espaciadas | `text` |
| `sheetCard(…)` | Tarjeta con cabecera (ícono dorado 18 px + título Georgia 16 + acción) | `icon`, `title`, `trailing`, `child` |
| `responsiveColumns(…)` | Columnas lado a lado ≥ 640, apiladas debajo | `List<List<Widget>>` |
| `appNavItem(…)` | Ítem del panel lateral | `icon`, `label`, `active`, `onTap` |

### Datos de personaje

| Componente | Qué es | Notas |
| --- | --- | --- |
| `StatTile` | Placa de la **banda táctica** de la ficha: rótulo con ícono arriba y cifra grande en sans negrita, todo alineado a la izquierda | `icon`, `labelTrailing`, `suffix` (unidad atenuada), `valueColor`, `footer` |
| `StatPlaque` | Rótulo en mayúsculas + valor grande en Georgia sobre `plaque`, centrado | Variante `dense` para tarjetas apretadas. `valueColor` cae a `gold`. Es la de las **tiras cortas dentro de una tarjeta** (carga, sintonizados, CD de salvación) |
| `AbilityPlaque` | Característica con el **modificador como cifra principal**, la puntuación rotulada debajo (`Punt. 20`) y la salvación competente nombrada (`SALV` con escudo) | Reserva el alto de la marca aunque no haya salvación, para que las seis alineen |
| `ShieldBadge` | La CA dentro de la silueta de escudo, borde dorado de 1.5 px | Escala con `height / 52`; **solo para CA**, y solo donde la CA es el tema (Defensa, Inventario) |
| `Medallion` | Círculo con aro dorado: retrato, emblema o inicial | Ver [Retratos](#9-retratos-y-medallones) |
| `ClassMedallion` | `Medallion` que resuelve solo el emblema y el acento de la clase | `class_visuals.dart` |
| `ThinBar` | Barra de progreso de 5 px con radio 3 | Para PG dentro de una placa |
| `UsagePips` | Tira de íconos para usos restantes: llenos en `gold`, gastados en `textMuted` | Recursos de clase, espacios de conjuro |
| `GoldPill` | Cápsula dorada suave; `highlighted: false` la vuelve neutra | Radio 20 |
| `SourceBadge` | `GoldPill` con la procedencia del contenido | Solo el SRD 5.2.1 va resaltado |

### Selección

| Componente | Qué es |
| --- | --- |
| `CappedChipSelect` | Multiselección de `FilterChip` con tope; al llegar al máximo, las no elegidas se deshabilitan |
| `_SingleSelect` | Selección única con `ChoiceChip`, con `SourceBadge` opcional por opción |
| `_WeaponSelect` / `_WeaponChecklist` | Pickers de armas con búsqueda y agrupación Simples/Marciales, **acotados a 300 px de alto con scroll propio** |
| `SpendRecoverButtons` | Par −/+ para gastar y restaurar un uso |

### Retroalimentación

| Componente | Qué es | Regla |
| --- | --- | --- |
| `showAppMessage(…)` | `SnackBar` con tono `info` / `success` / `error` | El error dura **6 s**, el resto 3 s. Siempre `Semantics(liveRegion: true)` |
| `AppBusyLabel` | Spinner de 18 px + texto, como región viva | El texto es obligatorio: un spinner solo no dice qué está pasando |
| `_SaveStatusIndicator` | Píldora de estado del guardado con `AnimatedSwitcher` de 180 ms | Ícono + texto + color, los tres |
| Estado vacío | Ícono 40 px `onSurfaceVariant` + mensaje centrado | Patrón, no widget: `_emptyState` |
| Error de arranque | Ícono 44 px de error + mensaje + `SelectableText` del detalle + botón "Reintentar" | El detalle técnico se puede copiar |

**Los diálogos siguen siempre el mismo molde**: `AlertDialog`, `TextButton`
"Cancelar" a la izquierda, `FilledButton` con el verbo de la acción a la
derecha.

---

## 9. Iconografía

**Material Icons exclusivamente.** No hay set propio ni SVG sueltos.

El contenido declara su ícono con un **id de texto** (`iconId` en el JSON) que
`class_visuals.dart` mapea a un `IconData` **const**. Nunca se construye un
`IconData` desde un codepoint variable: eso rompe el *tree-shaking* de íconos
de `flutter build` y mete la fuente entera en el bundle.

Cada dominio tiene su fallback y son distintos a propósito:

| Dominio | Fallback |
| --- | --- |
| Clase | `Icons.person_outline` |
| Especie | `Icons.groups` |
| Trasfondo | `Icons.badge_outlined` — **a propósito fuera del registro**, para que "sin ícono" se distinga de un ícono real |
| Genérico | `Icons.circle_outlined` |

Tamaños en uso: `14` (inline en metadatos), `17–18` (cabeceras, indicadores,
navegación), `20` (`SnackBar`, prefijos de campo), `40–44` (estados vacíos y de
error).

---

## 10. Movimiento

Poco y corto. Todo lo que anima está acá:

| Animación | Duración | Curva |
| --- | --- | --- |
| Hover de tarjeta (traslación + sombra + borde) | 120 ms | default de `AnimatedContainer` |
| Cambio de estado de guardado | 180 ms | `AnimatedSwitcher` |
| Arrastre de tarjeta | — | `opacity: 0.85` en el feedback, `0.3` en el hueco |

**No hay animaciones de entrada de página, ni de listas, ni parallax, ni
transiciones personalizadas de ruta.** Una herramienta que se abre cincuenta
veces por sesión no puede cobrar peaje de 300 ms cada vez.

---

## 11. Accesibilidad

### 11.1 Lo que ya está resuelto

- **Etiquetas semánticas en todos los widgets de datos**, con
  `excludeSemantics: true` para que el lector no lea el número suelto sin
  contexto: `AbilityPlaque` anuncia "FUE: modificador +3, puntuación 16,
  competente en salvación" —en ese orden, el mismo en que la plaqueta los
  muestra—; `ShieldBadge`, "Clase de armadura: 17"; `UsagePips`, "3 de 5 usos
  disponibles"; `StatTile`, "Velocidad: 30 pies".
- **Regiones vivas** en `SnackBar` y `AppBusyLabel`: lo que cambia solo se
  anuncia solo.
- **El color nunca va solo** (ver [3.4](#34-semántica-de-estado)).
- **`tooltip` en todo `IconButton`** sin etiqueta visible.
- Los retratos anuncian "Retrato de X" o "Emblema de X" según corresponda.
- Un 404 de retrato no rompe la pantalla: el medallón queda sin imagen
  (`onError` vacío deliberado).

### 11.2 Contraste medido (WCAG 2.1)

Ratios calculados sobre los tokens reales. **Verde** = AA para texto normal
(≥ 4.5). **Ámbar** = solo AA para texto grande o elementos no textuales
(≥ 3.0). **Rojo** = insuficiente.

**Tema oscuro**

| Combinación | Ratio | |
| --- | --- | --- |
| `onSurface` sobre `surface` | 14.20 | ✅ |
| `onSurfaceVariant` sobre `surface` | 5.82 | ✅ |
| `gold` sobre `surface` | 7.26 | ✅ |
| `gold` sobre `plaque` | 7.92 | ✅ |
| `onPrimary` sobre `gold` | 7.19 | ✅ |
| `crimson` sobre `surface` | 3.60 | ⚠️ solo texto grande |
| `textMuted` sobre `surface` | 3.62 | ⚠️ solo texto grande |

**Tema claro**

| Combinación | Ratio | |
| --- | --- | --- |
| `onSurface` sobre `surface` | 14.76 | ✅ |
| `onSurfaceVariant` sobre `surface` | 5.78 | ✅ |
| `crimson` sobre `surface` | 6.04 | ✅ |
| `gold` sobre `surface` | 4.71 | ✅ |
| `gold` sobre `plaque` | 3.85 | ⚠️ solo texto grande |
| `onPrimary` sobre `gold` | 3.42 | ❌ texto de botón relleno |
| `textMuted` sobre `surface` | 2.99 | ❌ |
| `textMuted` sobre `plaque` | 2.45 | ❌ |

### 11.3 Reglas que se derivan de lo anterior

1. **`textMuted` es solo para rótulos decorativos redundantes.** Nunca para
   información que exista únicamente ahí. Hoy se usa en eyebrows y rótulos de
   placa a 8.5–11 px, que es donde más falta hace el contraste y menos hay.
2. **`crimson` en oscuro no se usa para texto pequeño.** Los PG a 13 px en
   carmesí sobre la tarjeta están por debajo del umbral.
3. **`gold` sobre `plaque` en tema claro solo vale a 24 px o más.** Por eso la
   `StatPlaque` normal pasa y la variante `dense` (16 px) no.
4. Los objetivos táctiles siguen los mínimos de Material (48 px); los
   `IconButton` no se achican por debajo de eso.

---

## 12. Anti-patrones

Prohibiciones duras. Las primeras cuatro rompen pruebas o el build.

| ❌ No hacer | ✅ En su lugar | Por qué |
| --- | --- | --- |
| Calcular una regla de D&D en un widget | Leerla de `ComputedSheet` | El motor es la fuente de verdad; la UI que recalcula se desincroniza |
| Recorrer `klass.features` desde la UI | Preguntar a `ComputedSheet.featureChoiceSlots` | Contrato explícito entre motor y app |
| `IconData` desde un codepoint variable | Mapa `const` en `class_visuals.dart` | Rompe el tree-shaking de íconos |
| Concatenar rutas con `/` | `p.join` de `package:path` | Portabilidad |
| Color hexadecimal literal en un widget | `context.palette` o `colorScheme` | El tema claro deja de funcionar |
| `Colors.red` / `Colors.grey` | `colorScheme.error` / `onSurfaceVariant` | La paleta es el contrato |
| Sombra para separar superficies | Borde `hairline` de 1 px | El sistema es plano por decisión |
| Widget visual nuevo dentro de una pestaña | Extraerlo a `theme/app_widgets.dart` si se repite | Es la biblioteca compartida |
| `MediaQuery.of(context).size` para decidir layout | `LayoutBuilder` | El panel lateral resta 236 px que `MediaQuery` no sabe |
| `elevation` > 0 en `Card` | `elevation: 0` + borde | Material 3 tiñe de oro las superficies elevadas |
| Sumar un plugin nativo por comodidad | Verificar si se puede sin él | Obliga al Modo Desarrollador en toda máquina que compile |
| Texto largo sin `maxLines` en el panel | `maxLines: 1` + `TextOverflow.ellipsis` | El panel mide 236 px fijos |

---

## 13. Deuda conocida

Cosas ciertas hoy, documentadas para que no se re-descubran:

1. **Marca vieja en el wizard de creación.** El panel de progreso de
   `creation_wizard.dart:240` todavía dice "Fichas / D&D 5e" en vez de
   "Milantus / Asistente de Aventuras", que es lo que muestran el dashboard y
   la ficha. Es la única aparición del nombre viejo en `lib/`.
2. **Georgia no se empaqueta.** En sistemas sin la fuente, toda la capa display
   cae al serif genérico y la métrica cambia. Empaquetarla tiene costo de
   licencia y de peso; la alternativa sería una serif libre servida como asset.
3. **`textMuted` no llega a AA** en ninguno de los dos temas, y es justamente
   el token de los tamaños más chicos.
4. **`onPrimary` sobre `gold` claro (3.42)** deja el texto de los
   `FilledButton` por debajo de AA en tema claro.
5. **La escala de espaciado no es sistemática.** Conviven 2, 3, 5, 6, 7, 11 y
   13 con la escala canónica.
6. **`orientation: portrait-primary`** en `manifest.json` contradice un layout
   que está claramente pensado para escritorio ancho.

---

## Apéndice A — Tokens en JSON

Para herramientas de diseño y generación asistida. Los nombres coinciden
exactamente con los del código Dart.

```json
{
  "$schema": "milantus.design-tokens.v1",
  "brand": {
    "name": "Milantus",
    "subtitle": "Asistente de Aventuras",
    "defaultTheme": "dark"
  },
  "color": {
    "dark": {
      "scaffold": "#151210",
      "surface": "#1E1915",
      "onSurface": "#EFE7DA",
      "onSurfaceVariant": "#A2937E",
      "gold": "#C9A24B",
      "crimson": "#C24A3E",
      "plaque": "#12100C",
      "hairline": "#3A2F25",
      "goldSoft": "#2E2617",
      "textMuted": "#7F7059",
      "onPrimary": "#201A10"
    },
    "light": {
      "scaffold": "#F3ECDD",
      "surface": "#FBF7EC",
      "onSurface": "#2A2118",
      "onSurfaceVariant": "#6E5F49",
      "gold": "#8A6A1E",
      "crimson": "#A6392E",
      "plaque": "#EBE0C9",
      "hairline": "#D9C9A8",
      "goldSoft": "#EEE1BF",
      "textMuted": "#9E8E70",
      "onPrimary": "#201A10"
    },
    "classAccent": {
      "fighter": "#B0413E", "barbarian": "#C0552B", "rogue": "#7D6B99",
      "monk": "#2E86AB", "wizard": "#4A6FA5", "cleric": "#CBB26A",
      "druid": "#4C8B3F", "bard": "#D98E48", "sorcerer": "#C13B5A",
      "warlock": "#7E57C2", "paladin": "#C8A13A", "ranger": "#5B8C5A",
      "artificer": "#B08D57"
    }
  },
  "typography": {
    "display": { "family": "Georgia", "fallback": "serif" },
    "body": { "family": "Roboto", "fallback": "sans-serif" },
    "numericFeature": "tnum",
    "scale": {
      "appBarTitle": 20, "brand": 18, "cardName": 18, "cardTitle": 16,
      "abilityValue": 26, "statValue": 24, "statValueDense": 16,
      "shieldValue": 20, "body": 14, "navItem": 14, "meta": 12.5,
      "eyebrow": 11, "pill": 11, "statLabel": 10, "statLabelDense": 8.5
    },
    "letterSpacing": { "eyebrow": 1.6, "statLabel": 1.2, "tiny": 1.0 }
  },
  "radius": { "mark": 5, "input": 8, "nav": 9, "card": 12, "characterCard": 14, "pill": 20 },
  "border": { "hairline": 1, "accent": 2, "shield": 1.5 },
  "spacing": { "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 20, "2xl": 24, "3xl": 32 },
  "layout": {
    "sidebarWidth": 236,
    "pageMaxWidth": 760,
    "shellBreakpoint": 900,
    "sheetColumnsBreakpoint": 640,
    "grid": { "cardBaseWidth": 420, "cardBaseHeight": 212, "cardMaxExtent": 560, "spacing": 16, "maxScale": 1.3 }
  },
  "motion": { "hover": 120, "stateSwitch": 180 },
  "elevation": {
    "cardHover": { "color": "#00000046", "blur": 26, "offsetY": 10 }
  }
}
```

## Apéndice B — Equivalencia en CSS

**Solo para mockups y prototipos fuera de la aplicación.** El cliente real no
usa CSS: estos valores existen para que una maqueta HTML se vea como el
producto.

```css
:root {
  --scaffold: #151210;  --surface: #1E1915;
  --on-surface: #EFE7DA; --on-surface-variant: #A2937E;
  --gold: #C9A24B; --crimson: #C24A3E; --plaque: #12100C;
  --hairline: #3A2F25; --gold-soft: #2E2617; --text-muted: #7F7059;
  --on-primary: #201A10;

  --font-display: Georgia, 'Times New Roman', serif;
  --font-body: Roboto, system-ui, sans-serif;

  --radius-card: 12px; --radius-pill: 20px; --radius-nav: 9px;
  --border-hairline: 1px solid var(--hairline);
  --sidebar-width: 236px; --page-max-width: 760px;
}

:root[data-theme="light"] {
  --scaffold: #F3ECDD;  --surface: #FBF7EC;
  --on-surface: #2A2118; --on-surface-variant: #6E5F49;
  --gold: #8A6A1E; --crimson: #A6392E; --plaque: #EBE0C9;
  --hairline: #D9C9A8; --gold-soft: #EEE1BF; --text-muted: #9E8E70;
}

.card { background: var(--surface); border: var(--border-hairline);
        border-radius: var(--radius-card); box-shadow: none; }
.plaque { background: var(--plaque); border: var(--border-hairline);
          border-radius: var(--radius-card); }
.stat-value { font-family: var(--font-display); font-size: 24px;
              line-height: 1; color: var(--gold); font-variant-numeric: tabular-nums; }
.eyebrow { font-size: 11px; letter-spacing: 1.6px; font-weight: 500;
           text-transform: uppercase; color: var(--text-muted); }
.pill { background: var(--gold-soft); border: var(--border-hairline);
        border-radius: var(--radius-pill); padding: 2px 9px;
        font-size: 11px; color: var(--gold); }
```

---

## Referencias de código

| Tema | Archivo |
| --- | --- |
| Tokens y `ThemeData` | `packages/dnd_app/lib/theme/app_theme.dart` |
| Biblioteca de componentes | `packages/dnd_app/lib/theme/app_widgets.dart` |
| Íconos y acentos de contenido | `packages/dnd_app/lib/theme/class_visuals.dart` |
| Shell y grilla del dashboard | `packages/dnd_app/lib/ui/dashboard_screen.dart` + `ui/dashboard/` |
| Shell y tarjetas de la ficha | `packages/dnd_app/lib/ui/sheet_screen.dart` + `ui/sheet/` |
| Wizard de creación | `packages/dnd_app/lib/creation/` |
| Subida de nivel | `packages/dnd_app/lib/levelup/` |
| Shell HTML y PWA | `packages/dnd_app/web/index.html`, `web/manifest.json` |
| Colores de clase | `packages/dnd_engine/lib/assets/srd_2024/classes.json` |

Arquitectura general, comandos y criterios de contribución: `CLAUDE.md`.
