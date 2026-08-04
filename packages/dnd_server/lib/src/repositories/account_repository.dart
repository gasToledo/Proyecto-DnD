import 'package:postgres/postgres.dart';

/// Mapea el sujeto OIDC verificado (el `sub` del proveedor de identidad) a
/// una fila de cuenta propia. La propiedad de los datos vive en esta fila
/// (su `id`), nunca en el sujeto OIDC directamente: si el proveedor de
/// identidad cambiara, solo esta tabla necesitaría remapearse.
abstract class AccountRepository {
  /// Devuelve el id de cuenta para [oidcSubject], creándola si es la primera
  /// vez que ese sujeto se autentica.
  Future<String> findOrCreateByOidcSubject(String oidcSubject);
}

class PostgresAccountRepository implements AccountRepository {
  final Session _session;

  const PostgresAccountRepository(this._session);

  @override
  Future<String> findOrCreateByOidcSubject(String oidcSubject) async {
    final existing = await _session.execute(
      Sql.named('SELECT id FROM accounts WHERE oidc_subject = @subject'),
      parameters: {'subject': TypedValue(Type.text, oidcSubject)},
    );
    if (existing.isNotEmpty) {
      return existing.first.toColumnMap()['id'] as String;
    }

    final inserted = await _session.execute(
      Sql.named('''
        INSERT INTO accounts (oidc_subject) VALUES (@subject)
        RETURNING id
      '''),
      parameters: {'subject': TypedValue(Type.text, oidcSubject)},
    );
    return inserted.first.toColumnMap()['id'] as String;
  }
}
