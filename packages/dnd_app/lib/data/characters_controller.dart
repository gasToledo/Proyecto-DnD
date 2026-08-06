import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

enum CharacterSaveState { saved, saving, error }

/// Fuente de verdad en memoria de los personajes, respaldada por la API del
/// servidor (ver `design.md`, decisión D6: reemplaza al `CharacterStore` de
/// archivos, no lo porta). Notifica a la UI y persiste con **debounce** ante
/// cada cambio relevante, igual que la versión de escritorio: el debounce y
/// la cola de guardado serializada por personaje ya funcionan como el buffer
/// local con envío periódico que pide la capacidad `web-client` para el
/// estado de combate, sin necesidad de un mecanismo aparte.
class CharactersController extends ChangeNotifier {
  final ApiClient api;
  final List<Character> characters = [];
  final Map<String, Timer> _debouncers = {};

  /// Fecha de alta por id, tal como la informa el servidor. Vive acá y no en
  /// [Character] porque no es parte de la ficha: el documento lo escribe este
  /// cliente y no puede declarar cuándo entró a la cuenta.
  final Map<String, DateTime> _createdAt = {};
  final Map<String, Future<void>> _saveQueues = {};
  static const _debounce = Duration(milliseconds: 400);
  ApiException? _lastSaveError;
  bool _disposed = false;

  CharactersController(this.api);

  /// Sin equivalente en el servidor: un documento corrupto no existe como
  /// concepto en Postgres. Se conservan vacías para no obligar a la UI del
  /// dashboard a distinguir entre "no hay avisos" y "esta plataforma no los
  /// tiene".
  List<Object> get recoveryIssues => const [];
  List<Object> get migrationBackups => const [];

  ApiException? get lastSaveError => _lastSaveError;
  bool get isSaving => _debouncers.isNotEmpty || _saveQueues.isNotEmpty;
  CharacterSaveState get saveState => isSaving
      ? CharacterSaveState.saving
      : _lastSaveError != null
      ? CharacterSaveState.error
      : CharacterSaveState.saved;

  /// `true` si la carga falló por falta de conexión (no confundir con una
  /// cuenta que simplemente no tiene personajes, ver capacidad
  /// `web-client`).
  bool loadFailedOffline = false;

  Future<void> load() async {
    loadFailedOffline = false;
    try {
      final loaded = await api.listCharacters();
      characters
        ..clear()
        ..addAll([for (final s in loaded) s.character]);
      _createdAt
        ..clear()
        ..addEntries([
          for (final s in loaded) MapEntry(s.character.id, s.createdAt),
        ]);
    } on ApiException catch (e) {
      if (e.isOffline) {
        loadFailedOffline = true;
      } else {
        rethrow;
      }
    }
    notifyListeners();
  }

  /// Cuándo entró [id] a la cuenta. Para un personaje recién creado que
  /// todavía no volvió del servidor se usa la hora local: alcanza para que
  /// aparezca como el más nuevo hasta la próxima carga, que trae la de verdad.
  DateTime createdAtOf(String id) => _createdAt[id] ?? DateTime.now();

  /// Fecha de alta local para un personaje recién creado, siempre posterior a
  /// la del resto. Con el reloj a secas, dos personajes creados en el mismo
  /// milisegundo empatan y el orden por antigüedad entre ellos queda librado
  /// al azar; acá el último creado es siempre el más nuevo, que es lo que
  /// alguien espera al crear dos seguidos. La fecha real llega en la próxima
  /// carga.
  DateTime _nextLocalCreatedAt() {
    final now = DateTime.now();
    DateTime? latest;
    for (final at in _createdAt.values) {
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    if (latest == null || now.isAfter(latest)) return now;
    return latest.add(const Duration(milliseconds: 1));
  }

  void add(Character c) {
    characters.add(c);
    _createdAt[c.id] = _nextLocalCreatedAt();
    _scheduleSave(c, isNew: true);
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

  Future<void> remove(Character c) async {
    _debouncers.remove(c.id)?.cancel();
    await (_saveQueues[c.id] ?? Future<void>.value());
    await api.deleteCharacter(c.id);
    characters.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }

  void _scheduleSave(Character c, {bool isNew = false}) {
    _debouncers[c.id]?.cancel();
    _debouncers[c.id] = Timer(_debounce, () {
      _debouncers.remove(c.id);
      _enqueueSave(c, isNew: isNew);
      notifyListeners();
    });
  }

  /// El primer guardado de un personaje recién creado usa `create` (el
  /// servidor puede reasignarle el id si choca); los siguientes usan
  /// `upsert` sobre el id ya asignado. Si el servidor reasignó el id, el
  /// personaje en memoria se actualiza para que los guardados posteriores
  /// apunten al id correcto.
  Future<void> _enqueueSave(Character c, {bool isNew = false}) {
    final previous = _saveQueues[c.id] ?? Future<void>.value();
    late final Future<void> queued;
    queued = previous
        .then((_) async {
          if (isNew) {
            final stored = await api.createCharacter(c);
            if (stored.id != c.id) {
              final i = characters.indexWhere((x) => identical(x, c));
              if (i >= 0) characters[i] = stored;
            }
          } else {
            await api.upsertCharacter(c);
          }
          _lastSaveError = null;
        })
        .catchError((Object error) {
          _lastSaveError = error is ApiException
              ? error
              : ApiException(null, error.toString());
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

  /// Fuerza el guardado inmediato de lo pendiente.
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
    super.dispose();
  }
}
