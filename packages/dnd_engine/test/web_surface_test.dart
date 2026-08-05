import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Recorre el grafo de `export`/`import` alcanzable desde la barrera del
/// motor (`lib/dnd_engine.dart`) tal como lo resolvería un build web: para una
/// importación condicional (`import 'a.dart' if (dart.library.io) 'b.dart';`)
/// sigue solo la URI por defecto, que es la que se usa cuando `dart:io` no
/// está disponible. Si esa URI por defecto es `dart:io` en algún archivo del
/// grafo, el motor ha vuelto a quedar inhabilitado para compilar a web.
void main() {
  test('la barrera del motor no reintroduce dart:io en la superficie web', () {
    final libDir = Directory(p.join(p.current, 'lib'));
    final entryPoint = File(p.join(libDir.path, 'dnd_engine.dart'));
    expect(entryPoint.existsSync(), isTrue,
        reason: 'No se encontró lib/dnd_engine.dart desde ${p.current}');

    final visited = <String>{};
    final offenders = <String>[];
    final pending = <String>[entryPoint.path];

    while (pending.isNotEmpty) {
      final path = pending.removeLast();
      if (!visited.add(path)) continue;
      final file = File(path);
      if (!file.existsSync()) continue;

      for (final directive in _directives(file.readAsStringSync())) {
        final uris = _quotedUris(directive);
        if (uris.isEmpty) continue;
        final defaultUri = uris.first;

        if (defaultUri == 'dart:io') {
          offenders.add(path);
          continue;
        }
        if (defaultUri.startsWith('dart:') ||
            defaultUri.startsWith('package:')) {
          continue;
        }
        pending.add(p.normalize(p.join(p.dirname(path), defaultUri)));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Estos archivos, alcanzables desde dnd_engine.dart bajo '
          'resolución web, importan dart:io sin importación condicional: '
          '$offenders. Un build web del motor ya no compilaría. Si el '
          'archivo necesita dart:io, muévalo detrás de una importación '
          'condicional con un stub por defecto, como '
          'content_pack_loader_stub.dart / content_pack_loader_io.dart.',
    );
  });
}

/// Divide el contenido de un archivo en directivas `import`/`export`
/// (delimitadas por `;`, que nunca aparece dentro de una URI entre comillas).
Iterable<String> _directives(String source) sync* {
  for (final statement in source.split(';')) {
    final trimmed = statement.trimLeft();
    if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
      yield trimmed;
    }
  }
}

/// Todas las URIs entre comillas simples de una directiva, en orden. La
/// primera es la que usa la resolución sin `dart:io` (web); las siguientes
/// son alternativas de una importación condicional.
List<String> _quotedUris(String directive) =>
    RegExp("'([^']*)'").allMatches(directive).map((m) => m.group(1)!).toList();
