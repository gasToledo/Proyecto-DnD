import 'package:postgres/postgres.dart';

/// Devuelve la cuenta asociada al sujeto OIDC, creándola en su primer login.
Future<String> findOrCreateAccount(Session session, String oidcSubject) async {
  final existing = await session.execute(
    Sql.named('SELECT id FROM accounts WHERE oidc_subject = @subject'),
    parameters: {'subject': TypedValue(Type.text, oidcSubject)},
  );
  if (existing.isNotEmpty) {
    return existing.first.toColumnMap()['id'] as String;
  }

  final inserted = await session.execute(
    Sql.named('''
        INSERT INTO accounts (oidc_subject) VALUES (@subject)
        RETURNING id
      '''),
    parameters: {'subject': TypedValue(Type.text, oidcSubject)},
  );
  return inserted.first.toColumnMap()['id'] as String;
}
