import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/foundation.dart';

import 'character_store.dart';
import 'data_recovery.dart';

enum CharacterSaveState { saved, saving, error }

/// Fuente de verdad en memoria de los personajes, respaldada por
/// [CharacterStore]. Notifica a la UI y persiste con **debounce** ante cada
/// cambio relevante (brief §3.C.4 / §8).
class CharactersController extends ChangeNotifier {
  final CharacterStore store;
  final List<Character> characters = [];
  final Map<String, Timer> _debouncers = {};
  final Map<String, Future<void>> _saveQueues = {};
  static const _debounce = Duration(milliseconds: 400);
  Object? _lastSaveError;
  bool _disposed = false;

  CharactersController(this.store);

  List<DataRecoveryIssue> get recoveryIssues => store.recoveryIssues;
  List<DataMigrationBackup> get migrationBackups => store.migrationBackups;
  Object? get lastSaveError => _lastSaveError;
  bool get isSaving => _debouncers.isNotEmpty || _saveQueues.isNotEmpty;
  CharacterSaveState get saveState => isSaving
      ? CharacterSaveState.saving
      : _lastSaveError != null
      ? CharacterSaveState.error
      : CharacterSaveState.saved;

  Future<void> load() async {
    final loaded = await store.loadAll();
    characters
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  void add(Character c) {
    characters.add(c);
    _scheduleSave(c);
    notifyListeners();
  }

  /// Registra un cambio in situ (p.ej. edición de combate) → notifica + guarda.
  void touch(Character c) {
    _scheduleSave(c);
    notifyListeners();
  }

  /// Reemplaza un personaje por su copia editada (equipo, nivel, etc.).
  void replace(Character c) {
    final i = characters.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      characters[i] = c;
    } else {
      characters.add(c);
    }
    _scheduleSave(c);
    notifyListeners();
  }

  /// Importa personajes. Si un id ya existe, se le asigna uno nuevo (no
  /// sobrescribe datos existentes). Persiste el lote antes de cambiar la
  /// memoria, para no mostrar personajes que no llegaron a guardarse.
  Future<List<Character>> importCharactersDetailed(
    List<Character> incoming,
  ) async {
    final existingIds = characters.map((c) => c.id).toSet();
    final resolved = <Character>[];
    for (var i = 0; i < incoming.length; i++) {
      var c = incoming[i];
      if (existingIds.contains(c.id)) {
        var attempt = i;
        late String newId;
        do {
          newId = '${DateTime.now().microsecondsSinceEpoch}-${attempt++}';
        } while (existingIds.contains(newId));
        c = Character.fromJson(c.toJson()..['id'] = newId);
      }
      existingIds.add(c.id);
      resolved.add(c);
    }
    await store.saveAll(resolved);
    characters.addAll(resolved);
    notifyListeners();
    return resolved;
  }

  Future<int> importCharacters(List<Character> incoming) async {
    return (await importCharactersDetailed(incoming)).length;
  }

  Future<void> remove(Character c) async {
    _debouncers.remove(c.id)?.cancel();
    await (_saveQueues[c.id] ?? Future<void>.value());
    await store.delete(c.id);
    characters.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }

  void _scheduleSave(Character c) {
    _debouncers[c.id]?.cancel();
    _debouncers[c.id] = Timer(_debounce, () {
      _debouncers.remove(c.id);
      _enqueueSave(c);
      notifyListeners();
    });
  }

  Future<void> _enqueueSave(Character c) {
    final previous = _saveQueues[c.id] ?? Future<void>.value();
    late final Future<void> queued;
    queued = previous
        .then((_) async {
          await store.save(c);
          _lastSaveError = null;
        })
        .catchError((Object error) {
          _lastSaveError = error;
        })
        .whenComplete(() {
          if (identical(_saveQueues[c.id], queued)) {
            _saveQueues.remove(c.id);
          }
          if (!_disposed) notifyListeners();
        });
    _saveQueues[c.id] = queued;
    return queued;
  }

  /// Fuerza el guardado inmediato de lo pendiente (p.ej. al cerrar la app).
  Future<void> flush() async {
    for (final t in _debouncers.values) {
      t.cancel();
    }
    _debouncers.clear();
    for (final c in characters) {
      _enqueueSave(c);
    }
    await Future.wait(_saveQueues.values.toList());
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _debouncers.values) {
      t.cancel();
    }
    // ChangeNotifier.dispose no puede esperar I/O. El ciclo de vida de la app
    // llama flush antes; esta red adicional evita descartar cambios si otro
    // consumidor desecha el controlador directamente.
    for (final c in characters) {
      _enqueueSave(c);
    }
    super.dispose();
  }
}
