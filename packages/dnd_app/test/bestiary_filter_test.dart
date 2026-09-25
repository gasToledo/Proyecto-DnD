import 'package:dnd_app/ui/dm/bestiary_view.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContentRepository repo;
  late List<Creature> all;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    all = repo.creaturesSorted;
  });

  test('busca sin acentos ni mayúsculas', () {
    final eagle = repo.creature('eagle')!;

    expect(filterCreatures(all, query: 'aguila'), contains(eagle));
    expect(filterCreatures(all, query: 'ÁGUILA'), contains(eagle));
  });

  // El SRD en español llama «goblin» al monstruo y «(trasgo)» a su etiqueta.
  test('busca también en la línea de tipo', () {
    final goblin = repo.creature('goblin-warrior')!;
    expect(goblin.kind, contains('trasgo'));
    expect(goblin.name, isNot(contains('trasgo')));

    expect(filterCreatures(all, query: 'trasgo'), contains(goblin));
  });

  test('el rango de VD es inclusivo y deja afuera a las que no tienen', () {
    final result = filterCreatures(all, minCr: 1, maxCr: 3);

    // El valor esperado sale del catálogo, no de un número escrito a mano.
    final expected = all.where((c) => c.cr != null && c.cr! >= 1 && c.cr! <= 3);
    expect(result, expected.toList());
    expect(result.map((c) => c.cr), containsAll([1, 3]));
  });

  test('un solo extremo también deja afuera a las que no tienen VD', () {
    expect(all.where((c) => c.cr == null), isNotEmpty);
    expect(filterCreatures(all, maxCr: 30).any((c) => c.cr == null), isFalse);
  });

  test('el rango se combina con el tipo', () {
    final result = filterCreatures(
      all,
      typeId: 'beast',
      minCr: 0.25,
      maxCr: 0.5,
    );

    expect(result, isNotEmpty);
    for (final c in result) {
      expect(c.creatureType?.id, 'beast');
      expect(c.cr, anyOf(0.25, 0.5));
    }
  });

  test('por VD ordena ascendente, desempata por nombre y deja sin VD al '
      'final', () {
    final result = filterCreatures(all, sortByCr: true);

    expect(result, hasLength(all.length));
    final withCr = result.takeWhile((c) => c.cr != null).toList();
    expect(
      result.skip(withCr.length).every((c) => c.cr == null),
      isTrue,
      reason: 'las que no tienen VD van todas al final',
    );
    for (var i = 1; i < withCr.length; i++) {
      final a = withCr[i - 1], b = withCr[i];
      expect(a.cr! <= b.cr!, isTrue, reason: '${a.name} antes que ${b.name}');
      if (a.cr == b.cr) {
        expect(compareContentNames(a.name, b.name), lessThanOrEqualTo(0));
      }
    }
  });

  test('sin filtros devuelve el catálogo en el orden de entrada', () {
    expect(filterCreatures(all), all);
  });
}
