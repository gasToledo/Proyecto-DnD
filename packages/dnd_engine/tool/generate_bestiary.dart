// Genera las criaturas de `lib/assets/srd_2024/creatures.json` leyendo los
// perfiles del SRD 5.2.1 en español (`docs/Libros completos DnD/`).
//
//     dart tool/generate_bestiary.dart --check    # no escribe, compara
//     dart tool/generate_bestiary.dart            # escribe el catálogo
//
// Se corre a mano, no en CI: el PDF no se versiona dentro del paquete. La red
// de seguridad de lo que produce es `content_integrity_test`.
//
// Reparto de fuentes, que es la convención del proyecto (§1.1 de las
// instrucciones de corrección de datos) y no un detalle: **todo** el contenido
// —mecánica y texto— sale del PDF en español, que es la autoridad. De
// 5etools solo salen los **ids**, que son slugs ingleses congelados (§1.3) y
// el PDF no tiene; viven ya resueltos en `tool/data/bestiario_ids.json`, así
// que esta herramienta no necesita red.
//
// Que la única fuente parseada sea el PDF además elimina el riesgo de licencia
// por construcción: todo perfil impreso en `SP_SRD_CC_v5.2.1.pdf` es SRD 5.2.1
// bajo CC-BY. No hay ninguna bandera que se pueda leer mal.
//
// Un nombre sin id mapeado aborta la corrida: quedarse corto es seguro,
// sembrar contenido sin decidir su licencia no. Misma política que
// `generate_items.dart`.
//
// **El PDF está en metros y el catálogo en pies.** Se convierte ×10/3, también
// dentro de la prosa de rasgos y acciones.
//
// Esa conversión se validó contra las 80 criaturas que ya estaban cargadas a
// mano antes del import: CA, PG, velocidad, características, sentidos e idiomas
// coincidieron en las 80. Las únicas diferencias fueron seis familiares
// (diablillo, quasit, pseudodragón, duende, esfinge de las maravillas y
// esqueleto) a los que el catálogo no les había puesto VD porque solo se
// usaban como invocación.
//
// Hecho el import, `--check` ya no compara contra datos escritos a mano sino
// contra la salida anterior de esta misma herramienta: sirve como **detector de
// deriva**, o sea para que se caiga si alguien edita `creatures.json` a mano y
// el archivo deja de ser reproducible desde el PDF.

import 'dart:convert';
import 'dart:io';

/// Ruta del PDF, relativa a la raíz del repositorio.
const _pdfPath = 'docs/Libros completos DnD/SP_SRD_CC_v5.2.1.pdf';

/// `pdftotext` viene con Git para Windows. Hay que usar `-raw`: el PDF es a dos
/// columnas y `-layout` intercala mal el texto entre ellas (hubo un falso
/// positivo real con «Guerrero goblin» por eso).
const _pdftotext = r'C:\Program Files\Git\mingw64\bin\pdftotext.exe';

// ---------------------------------------------------------------------------
// Normalización del texto
// ---------------------------------------------------------------------------

/// Deja el volcado de `pdftotext` en líneas parseables.
///
/// El orden importa: los pies de página se sacan antes de unir las palabras
/// partidas, porque un pie puede caer justo entre las dos mitades de una
/// palabra y si no se saca primero queda pegado adentro de ella.
List<String> normalize(String raw) {
  final footer = RegExp(r'^\s*\d*\s*Documento de referencia del sistema');
  final pageNumber = RegExp(r'^\s*\d{1,3}\s*$');

  final lines = <String>[];
  for (var line in const LineSplitter().convert(raw)) {
    line = line
        // El signo menos del PDF es U+2212, no el guion ASCII: sin esto todo
        // modificador negativo parsea como basura.
        .replaceAll('\u2212', '-')
        // Espacio duro, que aparece en «10 000 PX» y en algunos alcances.
        .replaceAll('\u00A0', ' ')
        // Guion suave: es invisible y el PDF lo siembra en palabras que podr\u00EDa
        // cortar. Al unicornio le part\u00EDa \u00ABde da\u00F1o \u00ADradiante\u00BB y el tipo de
        // da\u00F1o dejaba de reconocerse.
        .replaceAll('\u00AD', '')
        .trimRight();
    if (footer.hasMatch(line)) continue;
    if (pageNumber.hasMatch(line)) continue;
    lines.add(line);
  }

  // Palabras partidas al final de la línea ("contun-\ndente"). Se une hacia
  // adelante para no perder el corte cuando la segunda mitad abre línea.
  final joined = <String>[];
  for (final line in lines) {
    if (joined.isNotEmpty && joined.last.endsWith('-')) {
      final prev = joined.removeLast();
      joined.add(prev.substring(0, prev.length - 1) + line.trimLeft());
    } else {
      joined.add(line);
    }
  }
  return joined;
}

// ---------------------------------------------------------------------------
// Metros a pies
// ---------------------------------------------------------------------------

/// Convierte una medida en metros a pies, con la equivalencia del propio libro
/// (1,5 m = 5 pies), o sea ×10/3.
///
/// El SRD usa una escala redonda, no la conversión física: 12 m son 40 pies
/// exactos y no 39,37. Por eso se multiplica por 10/3 y se redondea, en vez de
/// usar el factor real.
int metersToFeet(String meters) {
  final value = double.parse(meters.replaceAll(',', '.'));
  return (value * 10 / 3).round();
}

/// Reescribe en pies todas las medidas en metros de un texto.
///
/// Cubre las tres formas que imprime el libro: suelta ("18 m"), de rango
/// ("9/36 m") y con decimal ("1,5 m"). Se aplica también a la prosa de rasgos
/// y acciones, donde aparecen conos, radios y líneas.
String feetify(String text) {
  // Primero los rangos, porque «9/36 m» contiene un número suelto seguido de
  // «m» y la regla de abajo lo partiría al medio.
  text = text.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)/(\d+(?:,\d+)?) m\b'),
    (m) => '${metersToFeet(m[1]!)}/${metersToFeet(m[2]!)} pies',
  );
  return text.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?) m\b'),
    (m) => '${metersToFeet(m[1]!)} pies',
  );
}

// ---------------------------------------------------------------------------
// Corte en bloques
// ---------------------------------------------------------------------------

/// Un perfil recortado del PDF, todavía sin parsear.
class RawBlock {
  final String name;

  /// La línea de tipo, tamaño y alineamiento ("Gigante Grande, caótico
  /// malvado"), que es la que va justo antes de `CA:`.
  final String kind;

  /// Desde `CA:` hasta el arranque del perfil siguiente.
  final List<String> body;

  RawBlock({required this.name, required this.kind, required this.body});
}

/// Palabras con las que arranca la línea de tipo de un perfil. Es lo que ancla
/// el corte: contar líneas hacia atrás no sirve porque la línea de tipo **se
/// parte en dos** cuando es larga (los licántropos son «Monstruosidad Mediana
/// o Pequeña (licántropo), neutral / malvada»).
const _typeWords = [
  'Aberración',
  'Autómata',
  'Bestia',
  'Celestial',
  'Cieno',
  'Constructo',
  'Dragón',
  'Elemental',
  // Los enjambres son «Enjambre Mediano de bestias Diminutas»: no son de
  // ninguno de los tipos sueltos, y por eso `CreatureType.fromKind` les
  // devuelve null. Está bien que así sea: un enjambre no es una bestia y un
  // druida no puede transformarse en uno.
  'Enjambre',
  'Feérico',
  'Gigante',
  'Humanoide',
  'Infernal',
  'Monstruosidad',
  'Muerto viviente',
  'Planta',
];

bool _startsType(String line) => _typeWords.any(line.startsWith);

/// El nombre del perfil sale repetido: una vez como encabezado de página y otra
/// como título del bloque. Se queda con uno.
///
/// No siempre están pegados —entre los dos puede haber caído un pie de página,
/// ya removido— así que se compara contenido y no posición.
List<RawBlock> cutBlocks(List<String> lines) {
  final starts = _blockStarts(lines);
  final blocks = <RawBlock>[];

  for (var b = 0; b < starts.length; b++) {
    final start = starts[b];

    // Hacia atrás hasta la línea que abre el tipo; lo que haya entre ella y
    // `CA:` es la continuación del tipo y se vuelve a pegar.
    var k = start - 1;
    while (k > 0 && !_startsType(lines[k])) {
      k--;
    }
    if (k <= 0) continue;
    final kind = lines.sublist(k, start).map((l) => l.trim()).join(' ').trim();

    // El nombre es lo anterior al tipo, saltando la repetición del encabezado.
    var i = k - 1;
    while (i > 0 && lines[i].trim().isEmpty) {
      i--;
    }
    final name = lines[i].trim();
    final nameStart = (i > 0 && lines[i - 1].trim() == name) ? i - 1 : i;

    // El cuerpo llega hasta donde arranca el nombre del perfil siguiente.
    var end = lines.length;
    if (b + 1 < starts.length) {
      var n = starts[b + 1] - 1;
      while (n > start && !_startsType(lines[n])) {
        n--;
      }
      var m = n - 1;
      while (m > start && lines[m].trim().isEmpty) {
        m--;
      }
      end = (m > start && lines[m - 1].trim() == lines[m].trim()) ? m - 1 : m;
    }

    blocks.add(RawBlock(
      name: name,
      kind: kind,
      body: lines.sublist(start, end.clamp(start, lines.length)),
    ));
    // `nameStart` no se usa para recortar, pero deja explícito que la
    // repetición del encabezado se detectó y no se coló en el cuerpo anterior.
    assert(nameStart <= i);
  }
  return blocks;
}

// ---------------------------------------------------------------------------
// Vocabularios: del español del PDF a los ids del catálogo
// ---------------------------------------------------------------------------

const _abilityKeys = {
  'Fue': 'str',
  'Des': 'dex',
  'Con': 'con',
  'Int': 'int',
  'Sab': 'wis',
  'Car': 'cha',
};

/// Nombre de habilidad del PDF al id del motor.
///
/// Dos no coinciden con las etiquetas de `Skill` y por eso esta tabla existe:
/// el PDF dice «Conocimiento arcano» donde el motor dice «Arcanos», y escribe
/// «Juego de manos» con minúscula. No se tocan las etiquetas del motor: son las
/// que ya ve el jugador en su ficha.
const _skillIds = {
  'acrobacias': 'acrobatics',
  'trato con animales': 'animal-handling',
  'conocimiento arcano': 'arcana',
  'arcanos': 'arcana',
  'atletismo': 'athletics',
  'engaño': 'deception',
  'historia': 'history',
  'perspicacia': 'insight',
  'intimidación': 'intimidation',
  'investigación': 'investigation',
  'medicina': 'medicine',
  'naturaleza': 'nature',
  'percepción': 'perception',
  'interpretación': 'performance',
  'persuasión': 'persuasion',
  'religión': 'religion',
  'juego de manos': 'sleight-of-hand',
  'sigilo': 'stealth',
  'supervivencia': 'survival',
};

const _damageIds = {
  'ácido': 'acid',
  'contundente': 'bludgeoning',
  'frío': 'cold',
  'fuego': 'fire',
  'fuerza': 'force',
  'relámpago': 'lightning',
  'necrótico': 'necrotic',
  'perforante': 'piercing',
  'veneno': 'poison',
  'psíquico': 'psychic',
  'radiante': 'radiant',
  'cortante': 'slashing',
  'trueno': 'thunder',
};

/// Encabezados de sección, en el orden en que los imprime el libro.
const _sectionKinds = {
  'Atributos': 'trait',
  'Acciones': 'action',
  'Acciones adicionales': 'bonus',
  'Reacciones': 'reaction',
  'Acciones legendarias': 'legendary',
};

// ---------------------------------------------------------------------------
// Parseo de un perfil
// ---------------------------------------------------------------------------

/// Valor de desafío: el libro lo imprime como fracción («VD: 1/4»).
num? parseCr(String text) {
  final m = RegExp(r'^VD: (\d+)(?:/(\d+))?').firstMatch(text);
  if (m == null) return null;
  final whole = num.parse(m[1]!);
  return m[2] == null ? whole : whole / num.parse(m[2]!);
}

/// Una entrada de sección: «Nombre. Texto…».
///
/// Los saltos de línea del PDF no distinguen una entrada nueva de la
/// continuación de la anterior —el negrita del nombre se pierde al extraer—
/// así que se reconoce por forma: arranca la línea, empieza en mayúscula y
/// cierra con un punto y espacio en las primeras palabras.
final _entryStart = RegExp(r'^([A-ZÁÉÍÓÚÑ][^.:]{0,55}?)\.\s+(.*)$');

/// Palabras con las que arranca una oración, nunca el nombre de una acción.
///
/// Sin esto, una línea de continuación que empieza en mayúscula y trae un punto
/// temprano abre una entrada fantasma («El espectro estará bajo el control de
/// la aparición» quedaba como si fuera una acción del espectro).
const _prose = [
  'El ',
  'La ',
  'Los ',
  'Las ',
  'Un ',
  'Una ',
  'Si ',
  'Cuando ',
  'Mientras ',
  'Puede ',
  'Este ',
  'Esta ',
  'Cualquier ',
  'Además',
  'También',
  'Su ',
  'Sus ',
];

class ParsedEntry {
  final String name;
  final String text;
  final String kind;
  ParsedEntry(this.name, this.text, this.kind);
}

List<ParsedEntry> parseEntries(List<String> body) {
  final entries = <ParsedEntry>[];
  // Nada cuenta hasta el primer encabezado: antes de él están la tabla de
  // características y las líneas de Equipo/Sentidos/Idiomas/VD, que ya se
  // parsearon como campos y que si no se colarían como un rasgo llamado «MOD».
  var started = false;
  var kind = 'trait';
  String? name;
  final buffer = <String>[];

  void flush() {
    if (name == null) return;
    entries.add(ParsedEntry(name!, buffer.join(' ').trim(), kind));
    name = null;
    buffer.clear();
  }

  for (final line in body) {
    final trimmed = line.trim();
    if (_sectionKinds.containsKey(trimmed)) {
      flush();
      kind = _sectionKinds[trimmed]!;
      started = true;
      continue;
    }
    if (!started) continue;
    final m = _entryStart.firstMatch(trimmed);
    if (m != null && !_prose.any(m[1]!.startsWith)) {
      flush();
      name = m[1]!.trim();
      buffer.add(m[2]!);
    } else if (name != null) {
      buffer.add(trimmed);
    }
  }
  flush();
  return entries;
}

/// Convierte una entrada de acción en el mapa JSON del catálogo, extrayendo el
/// ataque si lo tiene.
Map<String, dynamic> actionJson(ParsedEntry e) {
  final json = <String, dynamic>{'name': e.name};
  final text = e.text;

  // `\w` no cubre las acentuadas, y sin esto se pierden justo «psíquico»,
  // «necrótico», «ácido», «frío» y «relámpago».
  const word = '[a-záéíóúñ]+';
  final bonus = RegExp(r'Tirada de ataque[^:]*: \+(\d+)').firstMatch(text);
  // El grupo de dados es opcional: las criaturas diminutas hacen daño fijo y el
  // libro lo imprime sin paréntesis («Acierto: 1 de daño cortante»).
  // `\s+` y no un espacio: el tipo de daño puede quedar en la línea siguiente.
  final hit = RegExp(
          'Acierto: (\\d+)(?:\\s+\\(([^)]+)\\))?\\s+de daño\\s+(?:de\\s+)?($word)')
      .firstMatch(text);

  if (bonus != null) {
    json['attackBonus'] = bonus[1]!;
    final reach = RegExp(r'alcance ([^.]+?)\.').firstMatch(text);
    if (reach != null) json['reach'] = reach[1]!.trim();
    if (hit != null) {
      json['damage'] = (hit[2] ?? hit[1]!).replaceAll(' ', '');
      final type = _damageIds[hit[3]!.toLowerCase()];
      if (type != null) json['damageType'] = type;
    }
    // Lo que sobra del texto del ataque (daño extra, estados) va a la
    // descripción: el modelo tiene un solo campo de daño y eso alcanza para
    // una pantalla de consulta.
    final rest =
        text.split(RegExp('de daño (?:de )?$word\\.\\s*')).skip(1).join(' ');
    if (rest.trim().isNotEmpty) json['description'] = rest.trim();
  } else {
    json['description'] = text;
  }

  if (e.kind != 'action') json['kind'] = e.kind;
  return json;
}

/// Arma la entrada del catálogo para un perfil recortado.
///
/// [id] y `source` no salen del PDF: los pone el llamador, que es quien sabe el
/// slug inglés congelado.
/// Etiquetas de la cabecera de un perfil. Sirven para dos cosas: encontrar cada
/// campo y saber dónde **termina**, porque una línea larga se parte y sigue en
/// la siguiente (al Oni la línea de Habilidades se le corta antes de
/// «Percepción +4», y la de Sentidos antes de «pasiva 14»).
const _fieldLabels = [
  'CA',
  'PG',
  'Velocidad',
  'Equipo',
  'Habilidades',
  'Resistencias',
  'Inmunidades',
  'Vulnerabilidades',
  'Sentidos',
  'Idiomas',
  'VD',
  'Usos de acciones legendarias',
];

/// Junta cada etiqueta con su valor, pegando las continuaciones de línea.
Map<String, String> parseFields(List<String> body) {
  final fields = <String, String>{};
  final labelStart = RegExp('^(${_fieldLabels.join('|')}): (.*)\$');
  String? current;

  for (final line in body) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (_sectionKinds.containsKey(trimmed)) break;
    final m = labelStart.firstMatch(trimmed);
    if (m != null) {
      current = m[1]!;
      fields[current] = m[2]!.trim();
    } else if (current != null) {
      // La tabla de características no es continuación de nada: corta.
      if (trimmed.startsWith('MOD.') ||
          RegExp(r'^(Fue|Int) \d').hasMatch(trimmed)) {
        current = null;
        continue;
      }
      fields[current] = '${fields[current]} $trimmed'.trim();
    }
  }
  return fields;
}

Map<String, dynamic> parseBlock(RawBlock block) {
  final body = block.body.map(feetify).toList();
  final text = body.join('\n');
  final fields = parseFields(body);
  String? field(String label) => fields[label];

  final json = <String, dynamic>{
    'name': block.name,
    'kind': feetify(block.kind),
  };

  final ac = RegExp(r'^CA: (\d+)').firstMatch(text);
  if (ac != null) json['ac'] = ac[1]!;
  final hp = RegExp(r'^PG: (\d+)', multiLine: true).firstMatch(text);
  if (hp != null) json['hp'] = hp[1]!;
  // Algunos perfiles del apéndice cierran la velocidad con punto; el catálogo
  // la guarda sin él.
  final speed = field('Velocidad');
  if (speed != null) json['speed'] = speed.replaceFirst(RegExp(r'\.$'), '');

  // Tabla de características: «Fue 19 +4 +4» es puntuación, modificador y
  // salvación. La salvación solo se guarda cuando difiere del modificador, que
  // es exactamente lo que significa tener competencia en ella.
  final scores = <String, int>{};
  final saves = <String, int>{};
  for (final m
      in RegExp(r'\b(Fue|Des|Con|Int|Sab|Car) (\d+) (-?\+?-?\d+) (-?\+?-?\d+)')
          .allMatches(text)) {
    final key = _abilityKeys[m[1]!]!;
    scores[key] = int.parse(m[2]!);
    final mod = int.parse(m[3]!.replaceAll('+', ''));
    final save = int.parse(m[4]!.replaceAll('+', ''));
    if (save != mod) saves[key] = save;
  }
  if (scores.isNotEmpty) json['abilityScores'] = scores;
  if (saves.isNotEmpty) json['savingThrows'] = saves;

  // Iniciativa: solo se guarda si no es el modificador de Destreza, porque el
  // motor ya cae a DES cuando falta.
  final init = RegExp(r'Iniciativa: (-?\+?-?\d+)').firstMatch(text);
  if (init != null && scores.containsKey('dex')) {
    final printed = int.parse(init[1]!.replaceAll('+', ''));
    final dexMod = ((scores['dex']! - 10) / 2).floor();
    if (printed != dexMod) json['initiativeBonus'] = printed;
  }

  final skillsLine = field('Habilidades');
  if (skillsLine != null) {
    final skills = <String, int>{};
    for (final part in skillsLine.split(',')) {
      final m = RegExp(r'^\s*(.+?)\s*([+-]\d+)\s*$').firstMatch(part);
      if (m == null) continue;
      final id = _skillIds[m[1]!.toLowerCase()];
      if (id != null) skills[id] = int.parse(m[2]!.replaceAll('+', ''));
    }
    if (skills.isNotEmpty) json['skills'] = skills;
  }

  // Resistencias, inmunidades y vulnerabilidades van juntas en una línea, tal
  // como las describe el campo `defenses` del modelo.
  final defenses = [
    for (final label in ['Resistencias', 'Inmunidades', 'Vulnerabilidades'])
      if (field(label) case final v?) '$label: $v',
  ].join('; ');
  if (defenses.isNotEmpty) json['defenses'] = defenses;

  final senses = field('Sentidos');
  if (senses != null) json['senses'] = senses;
  final languages = field('Idiomas');
  if (languages != null) json['languages'] = languages;

  final vd = RegExp(r'^VD: .*$', multiLine: true).firstMatch(text)?.group(0);
  if (vd != null) {
    final cr = parseCr(vd);
    if (cr != null) json['cr'] = cr;
  }

  // «Usos de acciones legendarias: 3 (4 en la guarida)». El número es el
  // presupuesto por ronda; la variante de guarida queda en el texto del perfil
  // y no se modela, porque la app no lleva guaridas.
  final legendary =
      RegExp(r'Usos de acciones legendarias: (\d+)').firstMatch(text);
  if (legendary != null) {
    json['legendaryActionsPerRound'] = int.parse(legendary[1]!);
  }

  final entries = parseEntries(body);
  final traits = [
    for (final e in entries)
      if (e.kind == 'trait') {'name': e.name, 'description': e.text},
  ];
  final actions = [
    for (final e in entries)
      if (e.kind != 'trait') actionJson(e),
  ];
  if (traits.isNotEmpty) json['traits'] = traits;
  if (actions.isNotEmpty) json['actions'] = actions;

  return json;
}

void main(List<String> args) async {
  final check = args.contains('--check');
  final root = Directory.current.path;
  final pdf = File('$root/../../$_pdfPath');
  if (!pdf.existsSync()) {
    stderr.writeln('No está el PDF en ${pdf.path}');
    exit(1);
  }

  final result = await Process.run(
    _pdftotext,
    ['-raw', '-enc', 'UTF-8', pdf.path, '-'],
    stdoutEncoding: utf8,
  );
  if (result.exitCode != 0) {
    stderr.writeln('pdftotext falló: ${result.stderr}');
    exit(1);
  }

  final lines = normalize(result.stdout as String);
  final blocks = cutBlocks(lines);
  stdout.writeln('Líneas normalizadas: ${lines.length}');
  stdout.writeln('Perfiles recortados: ${blocks.length}');

  // Nombres repetidos: si el corte estuviera mal, aparecerían duplicados o
  // nombres que en realidad son una línea de prosa.
  final names = <String, int>{};
  for (final b in blocks) {
    names[b.name] = (names[b.name] ?? 0) + 1;
  }
  final dupes = names.entries.where((e) => e.value > 1).toList();
  stdout.writeln('Nombres distintos: ${names.length}');
  if (dupes.isNotEmpty) {
    stdout.writeln(
        'Repetidos: ${dupes.map((e) => '${e.key}×${e.value}').join(', ')}');
  }

  if (check) {
    compareWithCatalog(blocks, root);
    return;
  }
  if (args.contains('--ids')) {
    buildIdMap(blocks, root, args);
    return;
  }
  writeCatalog(blocks, root);
}

/// Orden de las claves dentro de cada entrada, para que el JSON generado se lea
/// como el escrito a mano y el diff sea revisable.
const _keyOrder = [
  'id',
  'name',
  'source',
  'kind',
  'type',
  'size',
  'cr',
  'ac',
  'hp',
  'speed',
  'abilityScores',
  'savingThrows',
  'skills',
  'initiativeBonus',
  'senses',
  'passivePerception',
  'languages',
  'defenses',
  'legendaryActionsPerRound',
  'scalesWithSpellLevel',
  'traits',
  'actions',
];

Map<String, dynamic> _ordered(Map<String, dynamic> json) => {
      for (final k in _keyOrder)
        if (json.containsKey(k)) k: json[k],
      for (final e in json.entries)
        if (!_keyOrder.contains(e.key)) e.key: e.value,
    };

/// Funde lo parseado con el catálogo y lo escribe.
///
/// Reglas de fusión, en orden:
///
/// 1. Lo que no aparece en el PDF **se copia tal cual**. Eso cubre las 31
///    invocaciones por fórmula (espíritus, cañones, corceles), que están
///    escritas a mano y no tienen perfil en el capítulo de monstruos.
/// 2. Una entrada con `scalesWithSpellLevel` **nunca** se regenera, aunque su
///    nombre coincida: sus CA y PG son fórmulas y el PDF trae números.
/// 3. `source` se conserva de la entrada que ya existía. Un perfil impreso en
///    el SRD es `srd_2024`, pero decidir eso por una entrada ya clasificada
///    sería relicenciarla sola, y eso se decide a mano.
void writeCatalog(List<RawBlock> blocks, String root) {
  final idsFile = File('$root/tool/data/bestiario_ids.json');
  if (!idsFile.existsSync()) {
    stderr.writeln('Falta ${idsFile.path}: correr primero con --ids.');
    exit(1);
  }
  final ids =
      (jsonDecode(idsFile.readAsStringSync()) as Map).cast<String, String>();

  final file = File('$root/lib/assets/srd_2024/creatures.json');
  final existing = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final byId = {for (final c in existing) c['id'] as String: c};

  final generated = <String, Map<String, dynamic>>{};
  final skipped = <String>[];

  for (final block in blocks) {
    final id = ids[block.name];
    if (id == null) {
      skipped.add(block.name);
      continue;
    }
    final old = byId[id];
    if (old != null && old['scalesWithSpellLevel'] == true) {
      skipped.add('${block.name} (invocación por fórmula)');
      continue;
    }
    final json = parseBlock(block);
    generated[id] = _ordered({
      'id': id,
      ...json,
      'source': old?['source'] ?? 'srd_2024',
    });
  }

  // Primero lo que ya estaba, en su orden, y después lo nuevo alfabético: así
  // el diff muestra las entradas tocadas en su sitio y no una reordenación.
  final result = <Map<String, dynamic>>[];
  for (final c in existing) {
    result.add(generated[c['id']] ?? c);
  }
  final fresh = generated.entries
      .where((e) => !byId.containsKey(e.key))
      .map((e) => e.value)
      .toList()
    ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  result.addAll(fresh);

  file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(result)}\n');

  stdout.writeln('\nRegeneradas: ${generated.length - fresh.length}');
  stdout.writeln('Nuevas: ${fresh.length}');
  stdout.writeln(
      'Conservadas sin tocar: ${existing.length - (generated.length - fresh.length)}');
  stdout.writeln('Total: ${result.length}');
  if (skipped.isNotEmpty) {
    stdout.writeln('Salteadas: ${skipped.join(', ')}');
  }
}

/// Huella de un perfil: CA, PG y las seis características.
///
/// Es lo que permite aparear el PDF español con los ids ingleses sin traducir
/// un solo nombre. Sobre los 358 perfiles candidatos de 5etools no hay un solo
/// choque, así que identifica sin ambigüedad.
String fingerprint(Map<String, dynamic> json) {
  final s = (json['abilityScores'] as Map?)?.cast<String, dynamic>() ?? {};
  return [
    json['ac'],
    json['hp'],
    for (final k in ['str', 'dex', 'con', 'int', 'wis', 'cha']) s[k],
  ].join('/');
}

/// Deriva `tool/data/bestiario_ids.json` (nombre español → id inglés).
///
///     dart tool/generate_bestiary.dart --ids <bestiary-xmm.json> <bestiary-efa.json>
///
/// Es el **único** paso que necesita los archivos de 5etools, y se corre una
/// sola vez: el mapa queda commiteado y el generador después no toca la red.
/// Bajar los archivos de la revisión pineada que documenta
/// `reference_5etools_src`, y quedarse solo con las entradas `srd52`.
void buildIdMap(List<RawBlock> blocks, String root, List<String> args) {
  final paths = args.where((a) => a.endsWith('.json')).toList();
  if (paths.isEmpty) {
    stderr.writeln('Falta la ruta a los bestiarios de 5etools.');
    exit(1);
  }

  final byFingerprint = <String, String>{};
  for (final path in paths) {
    final data = jsonDecode(File(path).readAsStringSync()) as Map;
    for (final m in (data['monster'] as List).cast<Map<String, dynamic>>()) {
      // Solo SRD 5.2.1 y EFA: es la barrera de licencia, y se aplica acá
      // porque es el único punto donde entra contenido de 5etools.
      if (m['srd52'] != true && m['source'] != 'EFA') continue;
      final ac = m['ac'] is List
          ? (m['ac'][0] is Map ? m['ac'][0]['ac'] : m['ac'][0])
          : m['ac'];
      final key = [
        ac,
        (m['hp'] as Map?)?['average'],
        for (final k in ['str', 'dex', 'con', 'int', 'wis', 'cha']) m[k],
      ].join('/');
      byFingerprint.putIfAbsent(key, () => _slug(m['name'] as String));
    }
  }

  // Los ids ya congelados en el catálogo mandan sobre el slug derivado (§1.3).
  final file = File('$root/lib/assets/srd_2024/creatures.json');
  final existing = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final frozen = {
    for (final c in existing) c['name'] as String: c['id'] as String
  };

  final map = <String, String>{};
  final unmatched = <String>[];
  var confirmed = 0, conflicts = 0;

  for (final block in blocks) {
    final json = parseBlock(block);
    final id = byFingerprint[fingerprint(json)];
    if (id == null) {
      unmatched.add(block.name);
      continue;
    }
    final already = frozen[block.name];
    if (already != null) {
      if (already == id) {
        confirmed++;
      } else {
        conflicts++;
        stdout.writeln('  id congelado ≠ derivado: ${block.name} '
            '«$already» vs «$id»');
      }
      map[block.name] = already;
    } else {
      map[block.name] = id;
    }
  }

  stdout.writeln('\nApareados: ${map.length} de ${blocks.length}');
  stdout.writeln('Confirmados contra ids ya congelados: $confirmed '
      '(conflictos: $conflicts)');
  stdout.writeln('Sin aparear: ${unmatched.length}');
  for (final n in unmatched.take(30)) {
    stdout.writeln('  $n');
  }

  final out = File('$root/tool/data/bestiario_ids.json');
  final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  out.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
  stdout.writeln('Escrito ${out.path}');
}

/// Slug del nombre inglés, que es la forma de los ids del catálogo.
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// Contrasta lo parseado contra las criaturas que ya están cargadas a mano.
///
/// Es la prueba del parser: 86 perfiles cuyos números ya verificó una persona.
/// Si el PDF se lee mal —sobre todo la conversión de metros a pies— se cae acá
/// y no en la mesa.
///
/// Solo se comparan los campos **mecánicos**. Las acciones no: el catálogo
/// viejo no tenía dónde poner una acción adicional y las codificaba en el
/// nombre («Huida veloz (acción adicional)»), así que van a diferir a
/// propósito.
void compareWithCatalog(List<RawBlock> blocks, String root) {
  final file = File('$root/lib/assets/srd_2024/creatures.json');
  final existing = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final byName = {for (final c in existing) c['name'] as String: c};

  const compared = ['ac', 'hp', 'speed', 'cr', 'senses', 'languages'];
  var matched = 0;
  final problems = <String>[];

  for (final block in blocks) {
    final old = byName[block.name];
    if (old == null) continue;
    matched++;
    final fresh = parseBlock(block);

    for (final key in compared) {
      final a = old[key], b = fresh[key];
      if (a == null && b == null) continue;
      if ('$a' != '$b') {
        problems.add('${block.name}.$key: catálogo «$a» ≠ PDF «$b»');
      }
    }
    final oldScores = (old['abilityScores'] as Map?)?.cast<String, dynamic>();
    final newScores = (fresh['abilityScores'] as Map?)?.cast<String, dynamic>();
    if (oldScores != null && '$oldScores' != '$newScores') {
      problems.add('${block.name}.abilityScores: $oldScores ≠ $newScores');
    }
  }

  stdout.writeln('\nPerfiles del PDF que ya están en el catálogo: $matched');
  stdout.writeln('Discrepancias: ${problems.length}');
  for (final p in problems.take(40)) {
    stdout.writeln('  $p');
  }
  if (problems.length > 40) {
    stdout.writeln('  … y ${problems.length - 40} más');
  }
}

/// Índices de las líneas `CA: N Iniciativa: ...`, que es lo que marca sin
/// ambigüedad el arranque de un perfil.
List<int> _blockStarts(List<String> lines) {
  final re = RegExp(r'^CA: \d+ Iniciativa:');
  return [
    for (var i = 0; i < lines.length; i++)
      if (re.hasMatch(lines[i])) i,
  ];
}
