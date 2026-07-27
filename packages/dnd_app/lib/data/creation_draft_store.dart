import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import '../creation/creation_draft.dart';
import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'data_recovery.dart';

class CreationDraftSnapshot {
  final CreationStep step;
  final DateTime savedAt;
  final Map<String, dynamic> data;

  const CreationDraftSnapshot({
    required this.step,
    required this.savedAt,
    required this.data,
  });
}

class CreationDraftStore {
  static const formatVersion = 1;

  final String? dataRoot;
  final List<DataRecoveryIssue> recoveryIssues = [];

  CreationDraftStore({this.dataRoot});

  File get _file =>
      File(p.join(fichasDir('drafts', dataRoot), 'character-creation.json'));

  Future<CreationDraftSnapshot?> load() async {
    recoveryIssues.clear();
    if (!await _file.exists()) return null;
    try {
      final decoded = (jsonDecode(await _file.readAsString()) as Map)
          .cast<String, dynamic>();
      if (decoded['type'] != 'dnd_creation_draft') {
        throw const FormatException('Formato de borrador no compatible.');
      }
      final version = decoded['formatVersion'];
      if (version is! int || version < 1) {
        throw const FormatException('Versión de borrador inválida.');
      }
      if (version > formatVersion) {
        throw UnsupportedDataVersionException(
          dataType: 'borrador',
          found: version,
          supported: formatVersion,
        );
      }
      if (version != formatVersion) {
        throw const FormatException('Formato de borrador no compatible.');
      }
      final rawData = decoded['draft'];
      if (rawData is! Map) {
        throw const FormatException('El borrador no contiene elecciones.');
      }
      final stepName = decoded['step'];
      final step = CreationStep.values.where(
        (candidate) => candidate.name == stepName,
      );
      final savedAt = DateTime.tryParse(decoded['savedAt'] as String? ?? '');
      if (step.isEmpty || savedAt == null) {
        throw const FormatException('El borrador está incompleto.');
      }
      return CreationDraftSnapshot(
        step: step.single,
        savedAt: savedAt,
        data: rawData.cast<String, dynamic>(),
      );
    } on UnsupportedDataVersionException catch (error) {
      recoveryIssues.add(
        DataRecoveryIssue(
          originalPath: _file.path,
          recoveryPath: _file.path,
          error: error.toString(),
        ),
      );
      return null;
    } catch (error) {
      if (await _file.exists()) {
        recoveryIssues.add(
          await recoverCorruptFile(_file, error, dataRoot: dataRoot),
        );
      }
      return null;
    }
  }

  Future<void> save({
    required CreationStep step,
    required Map<String, dynamic> data,
  }) async {
    await writeJsonAtomic(_file, {
      'type': 'dnd_creation_draft',
      'formatVersion': formatVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'step': step.name,
      'draft': data,
    });
  }

  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}
