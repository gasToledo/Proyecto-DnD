import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/theme/class_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseo del color de acento y fallback', () {
    const fb = Color(0xFF000001);
    expect(classAccent(null, fb), fb, reason: 'sin clase → fallback');
    // Un color válido no devuelve el fallback y respeta el hex.
    const klass = CharacterClass(
      id: 'x',
      name: 'X',
      source: ContentSource.homebrew,
      hitDie: 8,
      accentColor: '#B0413E',
      iconId: 'shield',
    );
    expect(classAccent(klass, fb), const Color(0xFFB0413E));
    expect(classIcon(klass), Icons.shield);
    // Hex inválido → fallback, id de ícono desconocido → genérico.
    const bad = CharacterClass(
      id: 'y',
      name: 'Y',
      source: ContentSource.homebrew,
      hitDie: 8,
      accentColor: 'nope',
      iconId: 'inexistente',
    );
    expect(classAccent(bad, fb), fb);
    expect(classIcon(bad), Icons.person_outline);
  });

  test('cada clase oficial declara acento válido e ícono reconocido', () async {
    final repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    const fb = Color(0xFF000001);
    for (final klass in repo.classes.values) {
      expect(
        klass.accentColor,
        isNotNull,
        reason: '${klass.id} sin accentColor',
      );
      expect(
        classAccent(klass, fb),
        isNot(fb),
        reason: '${klass.id}: accentColor no parsea',
      );
      expect(
        classIcon(klass),
        isNot(Icons.person_outline),
        reason: '${klass.id}: iconId "${klass.iconId}" no está en el mapa',
      );
    }
  });

  test('cada especie y trasfondo declara su presentación visual', () async {
    final repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );

    for (final race in repo.races.values) {
      expect(race.iconId, isNotNull, reason: '${race.id} sin iconId');
      expect(
        raceIcon(race),
        isNot(Icons.groups),
        reason: '${race.id}: iconId "${race.iconId}" no está en el mapa',
      );
      expect(race.tagline, isNotNull, reason: '${race.id} sin tagline');
      expect(race.tagline, isNotEmpty);
      expect(
        race.description.trim(),
        isNotEmpty,
        reason: '${race.id} sin descripción',
      );
    }

    for (final bg in repo.backgrounds.values) {
      expect(bg.iconId, isNotNull, reason: '${bg.id} sin iconId');
      expect(
        backgroundIcon(bg),
        isNot(Icons.badge_outlined),
        reason: '${bg.id}: iconId "${bg.iconId}" no está en el mapa',
      );
      expect(bg.tagline, isNotNull, reason: '${bg.id} sin tagline');
      expect(bg.tagline, isNotEmpty);
    }
  });
}
