import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/foundation.dart';

import 'character_store.dart';

/// Fuente de verdad en memoria de los personajes, respaldada por
/// [CharacterStore]. Notifica a la UI y persiste con **debounce** ante cada
/// cambio relevante (brief §3.C.4 / §8).
class CharactersController extends ChangeNotifier {
  final CharacterStore store;
  final List<Character> characters = [];
  final Map<String, Timer> _debouncers = {};
  static const _debounce = Duration(milliseconds: 400);

  CharactersController(this.store);

  Future<void> load() async {
    final loaded = await store.loadAll();
    characters
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  void add(Character c) {
    characters.add(c);
    notifyListeners();
    _scheduleSave(c);
  }

  /// Registra un cambio in situ (p.ej. edición de combate) → notifica + guarda.
  void touch(Character c) {
    notifyListeners();
    _scheduleSave(c);
  }

  /// Reemplaza un personaje por su copia editada (equipo, nivel, etc.).
  void replace(Character c) {
    final i = characters.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      characters[i] = c;
    } else {
      characters.add(c);
    }
    notifyListeners();
    _scheduleSave(c);
  }

  /// Importa personajes. Si un id ya existe, se le asigna uno nuevo (no
  /// sobrescribe datos existentes). Devuelve cuántos se importaron.
  Future<int> importCharacters(List<Character> incoming) async {
    final existingIds = characters.map((c) => c.id).toSet();
    var count = 0;
    for (var i = 0; i < incoming.length; i++) {
      var c = incoming[i];
      if (existingIds.contains(c.id)) {
        final newId = '${DateTime.now().microsecondsSinceEpoch}-$i';
        c = Character.fromJson(c.toJson()..['id'] = newId);
      }
      existingIds.add(c.id);
      characters.add(c);
      await store.save(c); // guardado inmediato al importar
      count++;
    }
    notifyListeners();
    return count;
  }

  Future<void> remove(Character c) async {
    characters.removeWhere((x) => x.id == c.id);
    _debouncers.remove(c.id)?.cancel();
    notifyListeners();
    await store.delete(c.id);
  }

  void _scheduleSave(Character c) {
    _debouncers[c.id]?.cancel();
    _debouncers[c.id] = Timer(_debounce, () {
      store.save(c);
      _debouncers.remove(c.id);
    });
  }

  /// Fuerza el guardado inmediato de lo pendiente (p.ej. al cerrar la app).
  Future<void> flush() async {
    for (final t in _debouncers.values) {
      t.cancel();
    }
    _debouncers.clear();
    for (final c in characters) {
      await store.save(c);
    }
  }

  @override
  void dispose() {
    for (final t in _debouncers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
