import 'package:dnd_server/src/repositories/homebrew_repository.dart';

class InMemoryHomebrewRepository implements HomebrewRepository {
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> _byUser =
      {};

  @override
  Future<void> upsert(
    String userId,
    String category,
    String id,
    Map<String, dynamic> document,
  ) async {
    final byCategory = _byUser.putIfAbsent(userId, () => {});
    (byCategory.putIfAbsent(category, () => {}))[id] = document;
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> listForUser(
    String userId,
  ) async {
    final byCategory = _byUser[userId] ?? const {};
    return {
      for (final entry in byCategory.entries)
        entry.key: entry.value.values.toList(),
    };
  }

  @override
  Future<void> delete(String userId, String category, String id) async {
    _byUser[userId]?[category]?.remove(id);
  }
}
