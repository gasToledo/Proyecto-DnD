// Reescribe la descripción de cada objeto de `magic_items.json` con el texto
// del SRD 5.2.1 en español, leído con `pdftotext -raw`.
//
//     dart tool/extract_magic_item_text.dart
//
// Parchea, no genera: `generate_magic_items.py` sigue decidiendo qué objetos
// hay, su rareza, su precio y sus efectos. Solo la descripción sale de acá,
// porque la lectura por columnas de pdfplumber la dejaba rota: títulos en
// negrita metidos en medio de una oración, nombres en cursiva que faltaban
// («Meter un en el espacio extra-») y renglones de un objeto dentro de otro.
// `-raw` sigue el orden en que el PDF dibuja el texto, que es el de lectura; es
// lo mismo que usa `generate_bestiary.dart`.
//
// Después hay que correr `apply_magic_item_charges.dart` y `apply_voseo.dart`,
// que leen y reescriben esta misma descripción.

import 'dart:convert';
import 'dart:io';

import 'generate_bestiary.dart' show metersToFeet;

const _pdfPath = '../../referencias-locales/libros/SP_SRD_CC_v5.2.1.pdf';
const _pdftotext = r'C:\Program Files\Git\mingw64\bin\pdftotext.exe';
const _catalog = 'lib/assets/srd_2024/magic_items.json';

/// Páginas del capítulo de objetos mágicos, de «Aceite de etereidad» al
/// último objeto antes de los objetos conscientes.
const _firstPage = 228;
const _lastPage = 277;

/// La línea de tipo y rareza que sigue a cada título. Es lo que distingue el
/// título de un objeto del título de una tabla, que puede llamarse igual.
final _category = RegExp(
  r'^(Objeto maravilloso|Anillo|Arma|Armadura|Bastón|Cetro|Munición|'
  r'Pergamino|Poción|Varita|Vara|Escudo)(,| \()',
);

/// Un renglón que puede ser el título de un objeto: corto, con mayúscula y
/// sin puntuación final.
bool _looksLikeTitle(String line) =>
    line.length < 60 &&
    RegExp(r'^\p{Lu}', unicode: true).hasMatch(line) &&
    !RegExp(r'[.:,;]$').hasMatch(line);

/// Filas de tabla que abren renglón siempre: un rango («01–20 …»), el
/// encabezado de una tirada («1d100 Efecto», con mayúscula: «1d10 de daño» es
/// prosa) y las viñetas.
final _alwaysRow =
    RegExp(r'^(\d{1,3}–\d{1,3}\s|\d+d\d+\s+\p{Lu}|•)', unicode: true);

/// Fila con un número solo («3 Cofre»). Se confunde con la prosa que arranca
/// renglón con una medida («60 cm de diámetro»), así que solo abre renglón
/// debajo de otra fila.
final _numberRow = RegExp(r'^\d{1,3}\s');

/// Medidas que la regla general resolvería mal, con los valores del manual en
/// inglés: centímetros al lado de metros (convertir la mitad deja «90 cm × 5
/// pies») y volúmenes cúbicos, cuyo exponente el PDF deja en otro renglón.
const _medidasEspeciales = <(String, String)>[
  ('01–20 90 cm × 1,5 m', '01–20 3 pies × 5 pies'),
  (
    '60 cm de lado y 1,2 m de profundidad',
    '2 pies de lado y 4 pies de profundidad'
  ),
  (
    'Ventana (60 cm por 1,2 m, con una profundidad de hasta 60 cm)',
    'Ventana (2 pies por 4 pies, con una profundidad de hasta 2 pies)'
  ),
  ('1,2 m de altura y 60 cm de ancho', '4 pies de altura y 2 pies de ancho'),
  ('9 m de largo y 30 cm de ancho', '30 pies de largo y 1 pie de ancho'),
];

/// Tablas que el PDF dibuja en la página de otro objeto: en orden de lectura
/// quedan en medio de un texto ajeno. Van del título a su última fila, y se
/// mudan al final del objeto que las cita.
const _tablasFlotantes = <({String titulo, String ultima, String duenio})>[
  (
    titulo: 'Palancas del aparato del crustáceo',
    ultima: '10 La escotilla trasera se abre. La escotilla trasera se cierra.',
    duenio: 'Aparato del crustáceo',
  ),
];

List<String> _lines(String raw) {
  final footer = RegExp(r'^\s*Documento de referencia del sistema');
  final out = <String>[];
  var afterFooter = false;
  for (var line in const LineSplitter().convert(raw)) {
    line = line
        // Guion suave: invisible, y el PDF corta renglón justo después.
        .replaceAll('\u00AD', '')
        .replaceAll('\u00A0', ' ')
        .trim();
    if (footer.hasMatch(line)) {
      afterFooter = true;
      continue;
    }
    // El número de página va en el renglón siguiente al pie. Solo ese: una
    // tabla puede tener filas que son un número solo.
    if (afterFooter && RegExp(r'^\d{1,3}$').hasMatch(line)) {
      afterFooter = false;
      continue;
    }
    afterFooter = false;
    if (line.isNotEmpty) out.add(line);
  }
  return out;
}

/// Une los renglones del PDF en párrafos. El PDF no marca dónde termina un
/// párrafo, así que se infiere: un renglón que sigue en minúscula continúa la
/// oración; una fila de tabla abre renglón; después de un punto se abre otro.
String _reflow(List<String> lines) {
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i == 0) {
      out.write(line);
      continue;
    }
    final prev = lines[i - 1];
    final continues = RegExp(r'^\p{Ll}', unicode: true).hasMatch(line);
    if (prev.endsWith('-') && continues) {
      // Palabra partida: se saca el guion del corte.
      final s = out.toString();
      out
        ..clear()
        ..write(s.substring(0, s.length - 1))
        ..write(line);
    } else if (continues) {
      out.write(' $line');
    } else if (_alwaysRow.hasMatch(line) ||
        (_numberRow.hasMatch(line) &&
            (_alwaysRow.hasMatch(prev) || _numberRow.hasMatch(prev))) ||
        RegExp(r'[.:!?”"»)*]$').hasMatch(prev)) {
      out.write('\n$line');
    } else {
      out.write(' $line');
    }
  }
  return out.toString();
}

String _feetify(String text) {
  for (final (antes, despues) in _medidasEspeciales) {
    text = text.replaceAll(antes, despues);
  }
  text = text.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)/(\d+(?:,\d+)?) m(?![\p{L}\p{N}_])', unicode: true),
    (m) => '${metersToFeet(m[1]!)}/${metersToFeet(m[2]!)} pies',
  );
  return text.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?) m(?![\p{L}\p{N}_])', unicode: true),
    (m) {
      final feet = metersToFeet(m[1]!);
      return '$feet ${feet == 1 ? 'pie' : 'pies'}';
    },
  );
}

/// Título con que el PDF imprime un objeto del catálogo: las variantes +1, +2 y
/// +3 comparten una sola entrada.
String _heading(String name) =>
    name.replaceFirst(RegExp(r' \+[123]$'), ' +1, +2 o +3');

Future<void> main() async {
  final result = await Process.run(
      _pdftotext,
      [
        '-raw',
        '-enc',
        'UTF-8',
        '-f',
        '$_firstPage',
        '-l',
        '$_lastPage',
        _pdfPath,
        '-',
      ],
      stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    stderr.writeln('pdftotext falló: ${result.stderr}');
    exit(1);
  }
  final lines = _lines(result.stdout as String);
  final mudadas = <String, List<String>>{};
  for (final t in _tablasFlotantes) {
    final from = lines.indexOf(t.titulo);
    final to = lines.indexOf(t.ultima, from);
    if (from < 0 || to < 0) {
      stderr.writeln('No se encontró la tabla «${t.titulo}»');
      exit(1);
    }
    mudadas[t.duenio] = lines.sublist(from, to + 1);
    lines.removeRange(from, to + 1);
  }

  final file = File(_catalog);
  final items = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final wanted = {for (final item in items) _heading(item['name'] as String)};

  // Dónde empieza cada objeto: su título, con la línea de tipo abajo. Un
  // título largo puede ocupar dos renglones.
  final starts = <String, int>{};
  final boundaries = <int>{};
  for (var i = 0; i + 1 < lines.length; i++) {
    if (_category.hasMatch(lines[i + 1]) && wanted.contains(lines[i])) {
      starts[lines[i]] = i + 1;
      boundaries.add(i);
    } else if (i + 2 < lines.length &&
        _category.hasMatch(lines[i + 2]) &&
        wanted.contains('${lines[i]} ${lines[i + 1]}')) {
      starts['${lines[i]} ${lines[i + 1]}'] = i + 2;
      boundaries.add(i);
    } else if (_category.hasMatch(lines[i + 1]) && _looksLikeTitle(lines[i])) {
      // Un objeto que el catálogo no trae (los cetros) igual corta el texto
      // del anterior: si no, el Carillón de apertura se los tragaba.
      boundaries.add(i);
    }
  }
  final missing = wanted.difference(starts.keys.toSet());
  if (missing.isNotEmpty) {
    stderr.writeln('Sin título en el PDF: ${missing.join(', ')}');
    exit(1);
  }
  final sorted = boundaries.toList()..sort();

  var changed = 0;
  for (final item in items) {
    final start = starts[_heading(item['name'] as String)]!;
    final end = sorted.firstWhere((b) => b > start, orElse: () => lines.length);
    // La línea de tipo va sola en su renglón, como en el manual. Puede
    // seguir en el renglón de abajo («(requiere\nsintonización)»).
    var body = start + 1;
    while (
        body < end && RegExp(r'^\p{Ll}', unicode: true).hasMatch(lines[body])) {
      body++;
    }
    final heading = _heading(item['name'] as String);
    final text = _feetify([
      lines.sublist(start, body).join(' '),
      if (body < end)
        _reflow([...lines.sublist(body, end), ...?mudadas[heading]]),
    ].join('\n'));
    if (item['description'] != text) {
      changed++;
      item['description'] = text;
    }
  }
  stdout.writeln('$changed de ${items.length} descripciones cambian');
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(items)}\n',
  );
}
