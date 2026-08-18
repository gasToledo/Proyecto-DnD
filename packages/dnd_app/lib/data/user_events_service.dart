import '../api/api_client.dart';
import '../api/api_models.dart';

/// Lee y descarta los avisos que esperaban a esta cuenta.
///
/// Sin estado, igual que `SettingsService`: se construye donde hace falta y no
/// hay nada que cachear ni a quién notificar. Los avisos se muestran una vez y
/// se marcan vistos.
class UserEventsService {
  final ApiClient api;

  const UserEventsService(this.api);

  Future<List<UserEvent>> loadUnseen() => api.listUnseenEvents();

  Future<void> markSeen(List<UserEvent> events) {
    if (events.isEmpty) return Future.value();
    return api.markEventsSeen([for (final e in events) e.id]);
  }
}
