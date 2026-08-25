// Escribe `maxCharges` y `rechargeAmount` en los dos catálogos mágicos de
// `lib/assets/srd_2024/`, leyendo la descripción en español que ya trae cada
// objeto.
//
//     dart tool/apply_magic_item_charges.dart
//
// Parchea, no genera: `generate_magic_items.py` es el que produce el archivo
// desde el PDF, y este pasa después a completar las cargas —el mismo reparto
// que ya usan `generate_items.dart` y `weapons.json`—. Es idempotente: vuelve a
// calcular todo desde la descripción, así que correrlo dos veces no acumula.
//
// La descripción es la fuente porque es lo que el jugador lee en la ficha: si
// el texto dice "tiene 7 cargas", el contador tiene que decir 7. Los números
// que salen de acá se contrastaron uno por uno contra 5etools-src (revisión
// pineada, entradas con `srd52`), que es la fuente estructural del proyecto:
// coinciden los 50 del SRD. Los de Forge no están en 5etools y salen solo del
// texto, que en su caso no pasó por OCR.

import 'dart:convert';
import 'dart:io';

/// Objetos donde la palabra "carga" no habla de cargas. Sin esta lista el
/// chequeo final los reportaría como olvidos en cada corrida.
const _cargaEsOtraCosa = {
  'bolsa-de-contencion', // "hasta 250 kg de carga": peso
  'botas-de-zancadas-y-brincos', // peso
  'morral-practico', // peso
  'repeating-shot', // "ignora la propiedad Recarga": el nombre de la propiedad
};

/// Los cinco que el OCR del PDF dejó ilegibles para una regla general. Cada uno
/// se leyó a mano en el manual y se verificó contra 5etools; al lado va qué fue
/// lo que rompió el parseo, porque es lo único que no se ve en el JSON.
const _irregulares = <String, (int, String?)>{
  // "puedes gastar 1 de sus 3 cargas": el máximo no viene con el verbo "tener".
  // No recupera: el anillo se vuelve no mágico con la última carga.
  'anillo-de-los-tres-deseos': (3, null),
  // "tienen hechizar persona 3 cargas": el nombre del conjuro se metió entre el
  // verbo y el número. Recupera todas al amanecer.
  'anteojos-de-encantamiento': (3, todasLasCargas),
  // La descripción arranca con un pedazo de la columna anterior ("bastón
  // recupera 1d12 + 1 cargas.") que no es de este objeto. El suyo es 1d3.
  'baston-de-marchitamiento': (3, '1d3'),
  // "Estas botas tienen 4 cargas y recuperan 1d4": verbos en plural.
  'botas-aladas': (4, '1d4'),
  // La tabla de caras del cubo quedó intercalada en la frase de recarga.
  'cubo-de-fuerza': (10, '1d6'),
};

/// Objetos cuyo máximo se tira cuando aparecen ("1d3 cargas", "1d8 + 1
/// cargas"), así que no hay número que poner en el catálogo. Van con máximo 0,
/// que es como el modelo dice "las cuenta la mesa".
const _maximoVariable = {'filo-de-la-fortuna', 'ladrona-de-nueve-vidas'};

/// Ver `InventoryOps.todasLasCargas`. Duplicado acá y no importado porque las
/// herramientas no dependen del paquete compilado.
const todasLasCargas = 'todas';

final _max = RegExp(r'tienen? (\d+) cargas', caseSensitive: false);
final _recarga = RegExp(
  r'recuperan? (todas las|\d+d\d+(?: ?\+ ?\d+)?) cargas',
  caseSensitive: false,
);

void main() {
  // Los dos catálogos mágicos: el del SRD y el de Forge of the Artificer, que
  // tiene tres objetos con cargas y se generó aparte.
  for (final archivo in ['magic_items.json', 'efa_magic_items.json']) {
    _parchear(
        '${_repoRoot()}/packages/dnd_engine/lib/assets/srd_2024/$archivo');
  }
}

void _parchear(String path) {
  final data = _readJson(path);
  var conCargas = 0;
  final sinResolver = <String>[];

  for (final item in data) {
    final id = item['id'] as String;
    item.remove('maxCharges');
    item.remove('rechargeAmount');
    final texto = _plano(item['description'] as String? ?? '');
    if (!texto.toLowerCase().contains('carga')) continue;
    if (_cargaEsOtraCosa.contains(id)) continue;

    final (int max, String? recarga) = switch (id) {
      _ when _irregulares.containsKey(id) => _irregulares[id]!,
      _ when _maximoVariable.contains(id) => (0, null),
      _ => _leer(texto),
    };
    if (max < 0) {
      sinResolver.add(id);
      continue;
    }
    item['maxCharges'] = max;
    if (recarga != null) item['rechargeAmount'] = recarga;
    conCargas++;
  }

  if (sinResolver.isNotEmpty) {
    _fail(
      'No pude leer las cargas de: ${sinResolver.join(', ')}.\n'
      'Agregalos a _irregulares con el valor del manual, o a '
      '_cargaEsOtraCosa si su descripción usa la palabra para otra cosa.',
    );
  }
  _writeJson(path, data);
  stdout.writeln('${path.split('/').last}: $conCargas objetos con cargas.');
}

/// Máximo y recarga leídos del texto, o `(-1, null)` si no se entendió.
(int, String?) _leer(String texto) {
  final max = _max.firstMatch(texto);
  if (max == null) return (-1, null);
  final recarga = _recarga.firstMatch(texto)?.group(1);
  return (
    int.parse(max.group(1)!),
    switch (recarga?.toLowerCase()) {
      null => null,
      'todas las' => todasLasCargas,
      // El PDF escribe "1d4 +3" tanto como "1d4 + 3"; `DiceFormula` tolera las
      // dos, pero el catálogo guarda una sola forma.
      final f => f.replaceAll(RegExp(r' ?\+ ?'), ' + '),
    },
  );
}

/// El texto en una sola línea y sin los guiones de corte de renglón que deja el
/// PDF ("má-\ngica"), que son lo que parte las frases en dos.
String _plano(String descripcion) => descripcion
    .replaceAll('-\n', '')
    .replaceAll('\n', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

List<Map<String, dynamic>> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

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
