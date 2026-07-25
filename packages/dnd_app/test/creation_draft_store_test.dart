import 'dart:convert';
import 'dart:io';

import 'package:dnd_app/creation/creation_draft.dart';
import 'package:dnd_app/data/app_paths.dart';
import 'package:dnd_app/data/creation_draft_store.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('dnd-draft-test-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('guarda, recupera y limpia un borrador versionado', () async {
    final draft = CreationDraft(repo)
      ..raceId = 'human'
      ..backgroundId = 'soldier'
      ..name = 'Borrador'
      ..personalityTrait = 'Siempre alerta';
    for (var i = 0; i < Ability.values.length; i++) {
      draft.assignedScores[Ability.values[i]] = standardArray[i];
    }
    final store = CreationDraftStore(dataRoot: sandbox.path);

    await store.save(step: CreationStep.detalles, data: draft.toJson());
    final snapshot = await store.load();
    final restored = CreationDraft.fromJson(repo, snapshot!.data);

    expect(snapshot.step, CreationStep.detalles);
    expect(restored.raceId, 'human');
    expect(restored.backgroundId, 'soldier');
    expect(restored.name, 'Borrador');
    expect(restored.assignedScores, hasLength(6));

    await store.clear();
    expect(await store.load(), isNull);
  });

  test('aparta un borrador corrupto para recuperación', () async {
    final file = File(
      p.join(fichasDir('drafts', sandbox.path), 'character-creation.json'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('{roto');
    final store = CreationDraftStore(dataRoot: sandbox.path);

    expect(await store.load(), isNull);
    expect(store.recoveryIssues, hasLength(1));
    expect(await file.exists(), isFalse);
    expect(
      await File(store.recoveryIssues.single.recoveryPath).exists(),
      isTrue,
    );
  });

  test('conserva intacto un borrador de versión futura', () async {
    final file = File(
      p.join(fichasDir('drafts', sandbox.path), 'character-creation.json'),
    );
    await file.parent.create(recursive: true);
    final original = jsonEncode({
      'type': 'dnd_creation_draft',
      'formatVersion': CreationDraftStore.formatVersion + 1,
      'savedAt': DateTime(2026, 7, 24).toIso8601String(),
      'step': CreationStep.raza.name,
      'draft': const <String, dynamic>{},
    });
    await file.writeAsString(original);
    final store = CreationDraftStore(dataRoot: sandbox.path);

    expect(await store.load(), isNull);
    expect(store.recoveryIssues, hasLength(1));
    expect(store.recoveryIssues.single.wasMoved, isFalse);
    expect(await file.readAsString(), original);
  });
}
