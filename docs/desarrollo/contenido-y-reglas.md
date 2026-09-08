# Contenido y reglas

Guía vigente para modificar el catálogo de D&D de Milantus. Reemplaza las
instrucciones de corrección y la auditoría acumulativa de 2024, que mezclaban
estado actual con tareas ya cerradas.

## Alcance

Milantus implementa las reglas de 2024 y se mantiene únicamente como aplicación
web. Un cambio de contenido debe funcionar en todas las capas que alcance:
catálogo, dominio, personaje, compilador, servidor, cliente web y pruebas.

No se agrega compatibilidad de escritorio o móvil. Antes de crear un mecanismo,
se reutilizan los efectos y modelos existentes. Los campos nuevos son opcionales
cuando haga falta conservar compatibilidad con JSON anterior.

## Fuentes y precedencia

Las fuentes responden preguntas distintas:

1. El libro oficial de 2024 aplicable —Player's Handbook 2024 o *Eberron: Forge
   of the Artificer*— determina la mecánica de su contenido.
2. El SRD 5.2.1 oficial en español determina el contenido distribuible como
   `srd_2024` y es la autoridad para su texto y mecánica en español.
3. 5e.tools, filtrado por `XPHB` o `EFA`, sirve como fuente estructural para
   inventarios, identificadores y cruces; no sustituye al libro oficial.

No se incorporan reglas del PHB 2014, SRD 5.1 ni *Eberron: Rising from the Last
War*. Blogs, videos, wikias y resúmenes no son fuentes normativas.

Las procedencias persistidas son:

- `srd_2024`: contenido cubierto por SRD 5.2.1;
- `phb_2024`: contenido del PHB 2024 fuera del SRD;
- `foa_2025`: contenido de *Forge of the Artificer*.

`foa_2025` no se renombra: ya forma parte del contrato de datos.

## Reglas de implementación

- No cambiar identificadores existentes sin una migración explícita.
- Una descripción alcanza solo para reglas que no modifican estado ni valores
  que Milantus ya representa.
- Toda elección, competencia, conjuro concedido o recurso persistente debe
  modelarse y sobrevivir guardado, recarga, exportación e importación.
- Los documentos de usuario (`Character`, `Campaign`, `Chapter`, `Note`,
  `Encounter` y `EncounterLog`) usan esquema y migraciones. El catálogo no.
- No debilitar validaciones ni conteos para hacer pasar una modificación.
- Los cambios de contenido oficial deben preservar el fallback textual para
  homebrew antiguo cuando corresponda.

## Catálogo actual

Los conteos están fijados por
`packages/dnd_engine/test/content_integrity_test.dart`:

| Contenido | Cantidad |
|---|---:|
| Clases | 13 |
| Subclases | 53 |
| Especies | 15 |
| Linajes | 28 |
| Trasfondos | 33 |
| Dotes y opciones equivalentes | 189 |
| Armas | 38 |
| Armaduras | 13 |
| Conjuros | 392 |
| Criaturas | 367 |
| Objetos mágicos SRD | 261 |
| Objetos mágicos EFA | 9 |

Una variación debe ser deliberada y actualizar la prueba en el mismo cambio.

## Generación de catálogos

Las herramientas viven en `packages/dnd_engine/tool/`:

- `generate_bestiary.dart` genera `creatures.json` desde el PDF español y
  admite `--check` para comprobar reproducibilidad.
- `generate_items.dart` completa peso y precio de armas y armaduras.
- `generate_magic_items.py` genera el catálogo base de objetos mágicos.
- `apply_magic_item_charges.dart` aplica las cargas a los catálogos mágicos.

No se edita a mano un archivo generado. Si una extracción necesita una
excepción, se documenta en el generador y se cubre con una prueba.

## Verificación

Ejecutar primero las suites focalizadas del cambio. Antes de entregar una
modificación transversal:

```powershell
cd packages/dnd_engine
dart format --output=none --set-exit-if-changed lib test tool
dart analyze
dart test

cd ../dnd_server
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test

cd ../dnd_app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
```

Si cambió un documento persistido, probar su round-trip, la migración desde la
versión anterior y el rechazo de versiones futuras. Si cambió una experiencia
web, agregar la prueba de widget correspondiente y verificarla en navegador
cuando el riesgo lo justifique.

Una prueba automatizada o un build no demuestran una conexión real a
PostgreSQL, OIDC o servicios externos. Toda capa no ejecutada se declara como
limitación; no se marca como validada por inferencia.

## Límites deliberados vigentes

- «Lanzamiento de la Marca» registra su uso como recurso, pero el nivel y la
  restricción del espacio siguen descriptivos: modelarlos requiere un pozo de
  espacios separado.
- «Intuición Mejorada» de las marcas mayores sigue descriptiva porque el motor
  no representa bonificadores opcionales aplicados al momento de una tirada.
- Los conjuros de criaturas son navegables, pero sus usos diarios no se
  descuentan ni se persisten en `Encounter`.

Estos límites no son un backlog automático. Solo se implementan cuando exista
una necesidad de producto concreta.
