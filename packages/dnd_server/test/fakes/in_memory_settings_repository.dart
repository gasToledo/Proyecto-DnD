import 'package:dnd_server/src/repositories/settings_repository.dart';

class InMemorySettingsRepository implements SettingsRepository {
  final Map<String, Map<String, dynamic>> _byUser = {};

  @override
  Future<Map<String, dynamic>?> find(String userId) async => _byUser[userId];

  @override
  Future<void> save(String userId, Map<String, dynamic> document) async {
    _byUser[userId] = document;
  }
}
