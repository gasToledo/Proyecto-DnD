// Genera `lib/assets/srd_2024/items.json` y agrega peso y precio a
// `weapons.json` y `armor.json`, leyendo el capítulo 6 del Player's Handbook
// 2024 en `docs/Libros completos DnD/`.
//
//     dart tool/generate_items.dart
//
// Se corre a mano, no en CI: el markdown del manual no se versiona dentro del
// paquete. La red de seguridad de lo que produce es `content_integrity_test`.
//
// Reparto de fuentes, que es la convención del proyecto y no un detalle: la
// **mecánica** (peso, precio, cantidad) sale del markdown inglés, que ya viene
// en unidades imperiales y en tablas parseables; los **nombres visibles** salen
// del SRD 5.2.1 en español vía `tool/data/nombres_es.json`, porque traducir a
// ojo desde el inglés es exactamente como aparecen las colisiones de nombre.
// Un id sin nombre español aborta la corrida: quedarse corto es seguro, sembrar
// contenido sin decidir su licencia no.

import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';

/// Armaduras cuyo id del catálogo no es el slug de su nombre inglés. Los ids
/// están congelados (§1.3 de las instrucciones de corrección de datos), así que
/// manda el catálogo y no la tabla.
const _armorIds = <String, String>{
  'Padded Armor': 'padded',
  'Leather Armor': 'leather',
  'Studded Leather Armor': 'studded-leather',
  'Hide Armor': 'hide',
  'Chain Shirt': 'chain-shirt',
  'Scale Mail': 'scale-mail',
  'Breastplate': 'breastplate',
  'Half Plate Armor': 'half-plate',
  'Ring Mail': 'ring-mail',
  'Chain Mail': 'chain-mail',
  'Splint Armor': 'splint',
  'Plate Armor': 'plate',
  'Shield': 'shield',
};

/// Herramientas y variantes cuyo slug inglés no coincide con el id que ya usa
/// `proficiency_labels.dart`. Gana el id existente: el objeto y la competencia
/// tienen que ser el mismo id para que la ficha pueda cruzarlos.
const _toolIds = <String, String>{
  'poisoners-kit': 'poisoner-kit',
  'dice': 'dice-set',
  'dragonchess': 'dragonchess-set',
  'playing-cards': 'playing-card-set',
  'three-dragon-ante': 'three-dragon-ante-set',
};

/// Objetos del equipo de aventureros que existen para guardar otros objetos.
/// Es una categoría de presentación: el motor no la usa para nada.
const _containerIds = <String>{
  'backpack',
  'barrel',
  'basket',
  'bucket',
  'case-crossbow-bolt',
  'case-map-or-scroll',
  'chest',
  'pouch',
  'quiver',
  'sack',
};

/// Filas paraguas de la tabla de equipo: no son objetos sino el título de una
/// subtabla ("Ammunition", "Arcane Focus"). Se descartan porque las variantes
/// concretas se siembran desde esas subtablas.
const _umbrellaGear = <String>{
  'ammunition',
  'arcane-focus',
  'druidic-focus',
  'holy-symbol',
};

/// Herramientas genéricas que no son un objeto sino "una de esta familia a tu
/// elección". No se pueden llevar en la mochila —lo que llevás es un laúd, no
/// "un instrumento musical"— y por eso el catálogo siembra solo las variantes.
/// Es el mismo criterio con el que `proficiency_labels.dart` las deja fuera del
/// selector de competencias.
const _genericTools = <String>{'gaming-set', 'musical-instrument'};

/// Contenido de los siete paquetes del PHB 2024. Las cantidades salen de las
/// descripciones del capítulo 6; los nombres visibles se resuelven más abajo
/// con el mismo mapa español curado que usa el resto del catálogo.
const _packContents = <String, Map<String, int>>{
  'burglars-pack': {
    'backpack': 1,
    'ball-bearings': 1,
    'bell': 1,
    'candle': 10,
    'crowbar': 1,
    'lantern-hooded': 1,
    'oil': 7,
    'rations': 5,
    'rope': 1,
    'tinderbox': 1,
    'waterskin': 1,
  },
  'diplomats-pack': {
    'chest': 1,
    'clothes-fine': 1,
    'ink': 1,
    'ink-pen': 5,
    'lamp': 1,
    'case-map-or-scroll': 2,
    'oil': 4,
    'paper': 5,
    'parchment': 5,
    'perfume': 1,
    'tinderbox': 1,
  },
  'dungeoneers-pack': {
    'backpack': 1,
    'caltrops': 1,
    'crowbar': 1,
    'oil': 2,
    'rations': 10,
    'rope': 1,
    'tinderbox': 1,
    'torch': 10,
    'waterskin': 1,
  },
  'entertainers-pack': {
    'backpack': 1,
    'bedroll': 1,
    'bell': 1,
    'lantern-bullseye': 1,
    'costume': 3,
    'mirror': 1,
    'oil': 8,
    'rations': 9,
    'tinderbox': 1,
    'waterskin': 1,
  },
  'explorers-pack': {
    'backpack': 1,
    'bedroll': 1,
    'oil': 2,
    'rations': 10,
    'rope': 1,
    'tinderbox': 1,
    'torch': 10,
    'waterskin': 1,
  },
  'priests-pack': {
    'backpack': 1,
    'blanket': 1,
    'holy-water': 1,
    'lamp': 1,
    'rations': 7,
    'robe': 1,
    'tinderbox': 1,
  },
  'scholars-pack': {
    'backpack': 1,
    'book': 1,
    'ink': 1,
    'ink-pen': 1,
    'lamp': 1,
    'oil': 10,
    'parchment': 10,
    'tinderbox': 1,
  },
};

void main() {
  final root = _repoRoot();
  final phb = File(
    '$root/docs/Libros completos DnD/Player\'s Handbook (2024).md',
  );
  if (!phb.existsSync()) {
    _fail('No encuentro el manual en ${phb.path}.');
  }
  final chapter = _chapterSix(phb.readAsStringSync());
  final nombresEs = _readNombresEs(root);

  // --- Objetos nuevos ------------------------------------------------------
  final items = <Map<String, dynamic>>[
    ..._gear(chapter),
    ..._tools(chapter),
    ..._toolVariants(chapter),
    ..._subTable(
      chapter,
      'Ammunition',
      'ammunition',
      nameColumn: 0,
      amountColumn: 1,
    ),
    ..._subTable(chapter, 'Arcane Focuses', 'focus'),
    ..._subTable(chapter, 'Druidic Focuses', 'focus'),
    ..._subTable(chapter, 'Holy Symbols', 'focus'),
    {
      'id': 'spellbook',
      'name': 'Spellbook',
      'category': 'gear',
      'weight': 3,
      'costCp': 5000,
    },
  ];

  final seen = <String>{};
  for (final it in items) {
    if (!seen.add(it['id'] as String)) {
      _fail('Id repetido en el catálogo de objetos: ${it['id']}.');
    }
  }

  // Nombre español y procedencia. Un id sin entrada aborta: no se siembra nada
  // sin haber decidido de qué libro sale y bajo qué licencia.
  final sinNombre = <String>[];
  for (final it in items) {
    final id = it['id'] as String;
    final es = nombresEs[id];
    if (es == null) {
      sinNombre.add('$id  (${it['name']})');
      continue;
    }
    final tool = knownToolLabel(id);
    if (tool != null && tool != es) {
      _fail(
        'El objeto "$id" se llama "$es" pero la competencia se llama "$tool". '
        'Tienen que coincidir: son la misma herramienta.',
      );
    }
    it['name'] = es;
    it['source'] = ContentSource.srd2024.toJson();
    final contents = _packContents[id];
    if (contents != null) {
      final parts = <String>[];
      for (final entry in contents.entries) {
        final itemName = nombresEs[entry.key];
        if (itemName == null) {
          _fail('El contenido de "$id" referencia el objeto "${entry.key}" '
              'sin nombre español.');
        }
        parts.add(entry.value == 1 ? itemName : '${entry.value} × $itemName');
      }
      it['description'] = 'Contiene: ${parts.join(', ')}.';
    }
  }
  if (sinNombre.isNotEmpty) {
    _fail(
      'Estos ids no tienen nombre en tool/data/nombres_es.json. Agregalos '
      'desde el SRD 5.2.1 en español, o sacalos del catálogo si el objeto no '
      'está en el SRD:\n  ${sinNombre.join('\n  ')}',
    );
  }

  items.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  _writeJson('$root/packages/dnd_engine/lib/assets/srd_2024/items.json', items);

  // --- Peso y precio sobre armas y armaduras -------------------------------
  _patchWeapons(root, chapter);
  _patchArmor(root, chapter);

  stdout.writeln('items.json: ${items.length} objetos.');
}

// ---------------------------------------------------------------- secciones

/// El capítulo 6 completo, que es lo único que se parsea. Acotar la ventana
/// evita que una tabla de otro capítulo con encabezados parecidos se cuele.
String _chapterSix(String md) {
  final start = md.indexOf('# Chapter 6: Equipment');
  if (start < 0) _fail('El manual no tiene el capítulo 6.');
  final end = md.indexOf('\n# Chapter 7', start);
  return md.substring(start, end < 0 ? md.length : end);
}

/// Las filas de una tabla pipe titulada [heading], sin encabezado ni
/// separador, y sin las filas de sección (las que traen una sola celda, como
/// `| *Simple Melee Weapons* |`).
List<List<String>> _table(String chapter, String heading) {
  // Exactamente cinco almohadillas: las tablas del capítulo son `#####` y los
  // objetos y propiedades sueltos son `####`. Con `#{4,5}` la tabla de munición
  // se confundía con la propiedad "Ammunition", que se llama igual.
  final marker = RegExp('^#{5} ${RegExp.escape(heading)}\$', multiLine: true);
  final match = marker.firstMatch(chapter);
  if (match == null) _fail('No encuentro la tabla "$heading".');
  final rows = <List<String>>[];
  var header = 0;
  for (final line in chapter.substring(match.end).split('\n').skip(1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty && rows.isEmpty && header == 0) continue;
    if (!trimmed.startsWith('|')) break;
    if (trimmed.contains('---')) continue;
    final cells = trimmed
        .substring(1, trimmed.endsWith('|') ? trimmed.length - 1 : null)
        .split('|')
        .map((c) => c.trim())
        .toList();
    if (header++ == 0) continue;
    if (cells.length < 2) continue;
    rows.add(cells);
  }
  if (rows.isEmpty) _fail('La tabla "$heading" salió vacía.');
  return rows;
}

// ------------------------------------------------------------------ objetos

List<Map<String, dynamic>> _gear(String chapter) {
  final out = <Map<String, dynamic>>[];
  for (final row in _table(chapter, 'Adventuring Gear')) {
    final name = _cellName(row[0]);
    final id = _slug(name);
    if (_umbrellaGear.contains(id)) continue;
    out.add(
      _item(
        id: id,
        english: name,
        category: _containerIds.contains(id)
            ? 'container'
            : id.endsWith('-pack')
                ? 'pack'
                : 'gear',
        weight: _weight(row[1]),
        costCp: _cost(row[2]),
      ),
    );
  }
  return out;
}

/// Las 25 herramientas, que no están en una tabla sino como
/// `#### Smith's Tools (20 GP)` seguido de una viñeta `- **Weight:** 8 lb.`.
List<Map<String, dynamic>> _tools(String chapter) {
  final section = _slice(chapter, '## Tools', '## Adventuring Gear');
  final heading = RegExp(
    r'^#### (.+?) \((?:(Varies)|([\d,]+) (CP|SP|EP|GP|PP))\)$',
    multiLine: true,
  );
  final weight = RegExp(r'^- \*\*Weight:\*\* (.+)$', multiLine: true);
  final out = <Map<String, dynamic>>[];
  for (final m in heading.allMatches(section)) {
    final next = heading.firstMatch(section.substring(m.end));
    final body = section.substring(
      m.end,
      next == null ? section.length : m.end + next.start,
    );
    final name = m.group(1)!;
    final id = _toolId(_slug(name));
    if (_genericTools.contains(id)) continue;
    out.add(
      _item(
        id: id,
        english: name,
        category: 'tool',
        weight: _weight(weight.firstMatch(body)?.group(1) ?? '—'),
        costCp: m.group(2) != null ? 0 : _cost('${m.group(3)} ${m.group(4)}'),
      ),
    );
  }
  if (out.length != 23) {
    _fail('Esperaba 23 herramientas y encontré ${out.length}.');
  }
  return out;
}

/// Las variantes de Juego e Instrumento musical, que van en línea:
/// `- **Variants:** *Bagpipes* (30 GP, 6 lb.), *drum* (6 GP, 3 lb.), ...`
///
/// Son objetos comprables por derecho propio y además cada una es su propia
/// competencia, así que comparten id con `proficiency_labels.dart`.
List<Map<String, dynamic>> _toolVariants(String chapter) {
  final section = _slice(chapter, '## Tools', '## Adventuring Gear');
  final line = RegExp(r'^- \*\*Variants:\*\* (.+)$', multiLine: true);
  final variant = RegExp(
    r'\*?([A-Za-z][A-Za-z\- ]+?)\*? \(([\d,]+) (CP|SP|EP|GP|PP)(?:, (.+?))?\)',
  );
  final out = <Map<String, dynamic>>[];
  for (final l in line.allMatches(section)) {
    for (final m in variant.allMatches(l.group(1)!)) {
      final name = m.group(1)!.trim();
      out.add(
        _item(
          id: _toolId(_slug(name)),
          english: name,
          category: 'tool',
          weight: _weight(m.group(4) ?? '—'),
          costCp: _cost('${m.group(2)} ${m.group(3)}'),
        ),
      );
    }
  }
  if (out.length != 14) {
    _fail('Esperaba 14 variantes de herramienta y encontré ${out.length}.');
  }
  return out;
}

/// Subtablas de tres columnas (nombre, peso, precio). La munición tiene dos
/// columnas extra: el recipiente se compra aparte y la cantidad se conserva
/// para que la ficha pueda decir "paquete de 20".
List<Map<String, dynamic>> _subTable(
  String chapter,
  String heading,
  String category, {
  int nameColumn = 0,
  int? amountColumn,
}) {
  final rows = _table(chapter, heading);
  return [
    for (final row in rows)
      _item(
        id: _slug(_cellName(row[nameColumn])),
        english: _cellName(row[nameColumn]),
        category: category,
        weight: _weight(row[row.length - 2]),
        costCp: _cost(row.last),
        bundleSize: amountColumn == null
            ? 1
            : int.parse(row[amountColumn].replaceAll(',', '').trim()),
      ),
  ];
}

Map<String, dynamic> _item({
  required String id,
  required String english,
  required String category,
  required double weight,
  required int costCp,
  int bundleSize = 1,
}) =>
    // `name` y `source` los pisa el paso de nombres españoles; el inglés queda
    // solo para poder nombrar el id en el mensaje de error.
    {
      'id': id,
      'name': english,
      'source': ContentSource.homebrew.toJson(),
      'category': category,
      'weight': weight,
      'costCp': costCp,
      if (bundleSize != 1) 'bundleSize': bundleSize,
    };

// ------------------------------------------------------------------ parcheo

void _patchWeapons(String root, String chapter) {
  final path = '$root/packages/dnd_engine/lib/assets/srd_2024/weapons.json';
  final data = _readJson(path);
  final byId = {for (final w in data) w['id'] as String: w};
  var patched = 0;
  for (final row in _table(chapter, 'Weapons')) {
    if (row.length < 6) continue;
    final id = _slug(_cellName(row[0]));
    final entry = byId[id];
    if (entry == null) _fail('El arma "$id" no está en weapons.json.');
    entry['weight'] = _weight(row[4]);
    entry['costCp'] = _cost(row[5]);
    patched++;
  }
  if (patched != data.length) {
    _fail('Parcheé $patched de ${data.length} armas.');
  }
  _writeJson(path, data);
  stdout.writeln('weapons.json: $patched armas con peso y precio.');
}

void _patchArmor(String root, String chapter) {
  final path = '$root/packages/dnd_engine/lib/assets/srd_2024/armor.json';
  final data = _readJson(path);
  final byId = {for (final a in data) a['id'] as String: a};
  var patched = 0;
  for (final row in _table(chapter, 'Armor')) {
    if (row.length < 6) continue;
    final english = _cellName(row[0]);
    final id = _armorIds[english];
    if (id == null) _fail('La armadura "$english" no tiene id mapeado.');
    final entry = byId[id];
    if (entry == null) _fail('La armadura "$id" no está en armor.json.');
    entry['weight'] = _weight(row[4]);
    entry['costCp'] = _cost(row[5]);
    patched++;
  }
  if (patched != data.length) {
    _fail('Parcheé $patched de ${data.length} armaduras.');
  }
  _writeJson(path, data);
  stdout.writeln('armor.json: $patched armaduras con peso y precio.');
}

// ------------------------------------------------------------------ helpers

/// El nombre visible de una celda de tabla.
///
/// Si la celda arranca en cursiva, el nombre es lo que va entre asteriscos y lo
/// de después es una glosa: `*Staff* (also a *Quarterstaff*)` → "Staff". Si no
/// hay cursiva, el paréntesis es parte del nombre:
/// `Spell Scroll (Cantrip)` → "Spell Scroll (Cantrip)".
String _cellName(String cell) {
  final italic = RegExp(r'^\*(.+?)\*').firstMatch(cell.trim());
  return (italic?.group(1) ?? cell).trim();
}

String _slug(String name) => name
    .toLowerCase()
    .replaceAll("'", '')
    .replaceAll('’', '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _toolId(String slug) => _toolIds[slug] ?? slug;

/// Peso en libras. La tabla trae `—`, `Varies`, medios (`1½ lb.`, `1/2 lb.`) y
/// alguna acotación (`5 lb. (full)`). Lo no numérico vale 0.
double _weight(String raw) {
  final text = raw.replaceAll('½', '.5').replaceAll(',', '');
  final fraction = RegExp(r'(\d+)/(\d+)').firstMatch(text);
  if (fraction != null) {
    return int.parse(fraction.group(1)!) / int.parse(fraction.group(2)!);
  }
  final number = RegExp(r'\d+(\.\d+)?').firstMatch(text);
  return number == null ? 0 : double.parse(number.group(0)!);
}

/// Precio en piezas de cobre. `—` y `Varies` valen 0.
int _cost(String raw) {
  final m = RegExp(r'([\d,]+)\s*(CP|SP|EP|GP|PP)').firstMatch(raw);
  if (m == null) return 0;
  final amount = int.parse(m.group(1)!.replaceAll(',', ''));
  const perCoin = {'CP': 'cp', 'SP': 'sp', 'EP': 'ep', 'GP': 'gp', 'PP': 'pp'};
  return amount * coinValueCp[perCoin[m.group(2)]]!;
}

String _slice(String text, String from, String to) {
  final start = text.indexOf(from);
  final end = text.indexOf(to, start);
  return text.substring(start, end < 0 ? text.length : end);
}

Map<String, String> _readNombresEs(String root) {
  final file = File('$root/packages/dnd_engine/tool/data/nombres_es.json');
  if (!file.existsSync()) _fail('Falta ${file.path}.');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, String>();
}

List<Map<String, dynamic>> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

/// Escribe con dos espacios de sangría y salto final, que es como están los
/// demás catálogos: así el diff de una regeneración muestra solo lo que cambió.
void _writeJson(String path, List<Map<String, dynamic>> data) {
  File(path).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n',
  );
}

String _repoRoot() =>
    Directory.fromUri(Platform.script.resolve('../../..')).path;

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
