import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elección de tamaño en el wizard: gating, poda al cambiar de especie y
/// round-trip del borrador.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  test('el paso Raza bloquea hasta elegir el tamaño', () {
    final d = CreationDraft(repo)..raceId = 'human';
    expect(d.sizeOptions, ['Mediano', 'Pequeño']);
    expect(d.pendingFor(CreationStep.raza), ['Elegí el tamaño de la especie.']);

    d.chosenSize = 'Pequeño';
    expect(d.pendingFor(CreationStep.raza), isEmpty);
  });

  test('una especie de tamaño fijo no bloquea', () {
    final d = CreationDraft(repo)..raceId = 'goliath';
    expect(d.sizeOptions, isEmpty);
    // El Goliat sí exige linaje, así que se comprueba que lo que falta no es
    // el tamaño.
    expect(
      d.pendingFor(CreationStep.raza),
      isNot(contains('Elegí el tamaño de la especie.')),
    );
  });

  test('un tamaño inventado no desbloquea el paso', () {
    final d = CreationDraft(repo)
      ..raceId = 'human'
      ..chosenSize = 'Enorme';
    expect(d.pendingFor(CreationStep.raza), ['Elegí el tamaño de la especie.']);
  });

  test('el personaje construido lleva el tamaño elegido', () {
    final d = CreationDraft(repo)
      ..raceId = 'tiefling'
      ..lineageId = 'tiefling-infernal'
      ..chosenSize = 'Pequeño';
    expect(d.build().chosenSize, 'Pequeño');
  });

  test('un tamaño que la especie no ofrece no llega al personaje', () {
    // Estado alcanzable si se cambia de especie sin pasar por el selector.
    final d = CreationDraft(repo)
      ..raceId = 'goliath'
      ..chosenSize = 'Pequeño';
    expect(d.build().chosenSize, isNull);
  });

  test('el borrador conserva el tamaño al guardarse', () {
    final d = CreationDraft(repo)
      ..raceId = 'aasimar'
      ..chosenSize = 'Pequeño';
    final restored = CreationDraft.fromJson(repo, d.toJson());
    expect(restored.chosenSize, 'Pequeño');
  });

  test('al restaurar descarta un tamaño que la especie no ofrece', () {
    final d = CreationDraft(repo)..raceId = 'human';
    final json = d.toJson()..['chosenSize'] = 'Grande';
    expect(CreationDraft.fromJson(repo, json).chosenSize, isNull);
  });

  test('la ficha de previsualización refleja el tamaño elegido', () {
    // La firma del caché incluye el tamaño: sin eso, cambiarlo no recompilaba.
    final d = CreationDraft(repo)
      ..raceId = 'human'
      ..classId = 'fighter'
      ..backgroundId = 'soldier'
      ..chosenSize = 'Mediano';
    expect(d.previewSheet.size, 'Mediano');

    d.chosenSize = 'Pequeño';
    expect(d.previewSheet.size, 'Pequeño');
  });
}
