import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El contenido guarda los tipos de daño por su id en inglés, que es la clave
/// estable. La traducción vive en un solo lugar y esta prueba la fija.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('los 13 tipos de daño tienen su nombre del PHB', () {
    expect(DamageType.values, hasLength(13));
    expect(DamageType.labelFor('acid'), 'Ácido');
    expect(DamageType.labelFor('bludgeoning'), 'Contundente');
    expect(DamageType.labelFor('slashing'), 'Cortante');
    expect(DamageType.labelFor('piercing'), 'Perforante');
    expect(DamageType.labelFor('force'), 'Fuerza');
    expect(DamageType.labelFor('lightning'), 'Relámpago');
    expect(DamageType.labelFor('thunder'), 'Trueno');
  });

  test('un estado que viaja por el mismo campo también se traduce', () {
    // El Artífice es inmune a `poisoned`, que es un estado y no un tipo de
    // daño: comparten campo, así que la etiqueta tiene que cubrir ambos.
    expect(DamageType.fromId('poisoned'), isNull);
    expect(DamageType.labelFor('poisoned'), 'Envenenado');
  });

  test('un id desconocido no rompe: cae al id capitalizado', () {
    expect(DamageType.labelFor('vorpalidad'), 'Vorpalidad');
    expect(DamageType.labelFor(''), '');
  });

  test('todo tipo de daño del pack oficial tiene traducción', () {
    // La red real: si alguien agrega contenido con un tipo nuevo, esto falla
    // en vez de mostrarlo en inglés en la ficha.
    final sinTraducir = <String>{};
    void revisar(String id) {
      if (DamageType.fromId(id) == null &&
          DamageType.labelFor(id) == _titleCase(id)) {
        sinTraducir.add(id);
      }
    }

    for (final w in repo.weapons.values) {
      revisar(w.damageType);
    }
    for (final effects in [
      for (final r in repo.races.values) r.effects,
      for (final l in repo.lineages.values)
        for (final f in l.features) f.effects,
      for (final s in repo.subclasses.values)
        for (final f in s.features) f.effects,
    ]) {
      for (final e in effects) {
        if (e is ResistanceEffect) revisar(e.damageType);
        if (e is ImmunityEffect) revisar(e.damageType);
      }
    }

    expect(sinTraducir, isEmpty,
        reason: 'tipos sin traducción en el pack: $sinTraducir');
  });
}

String _titleCase(String s) => s.isEmpty
    ? s
    : s
        .split(RegExp(r'[-_ ]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
