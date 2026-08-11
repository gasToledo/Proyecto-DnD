/// Una migración de esquema con nombre estable. El nombre (no un número
/// suelto) es lo que queda registrado como aplicado, así que insertar una
/// migración en medio de la lista no desordena el historial de otra
/// instalación.
class Migration {
  final String id;
  final String sql;

  const Migration({required this.id, required this.sql});
}

/// Migraciones en el orden en que deben aplicarse. Cada entrada es
/// acumulativa e irreversible, igual que las de `Character.migrateJson`:
/// nunca se edita una ya publicada, solo se agregan nuevas al final.
const List<Migration> migrations = [
  Migration(
    id: '0001_init',
    sql: '''
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE characters (
  user_id UUID NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  document JSONB NOT NULL,
  name TEXT NOT NULL GENERATED ALWAYS AS (document ->> 'name') STORED,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, id)
);

CREATE INDEX characters_user_id_name_idx ON characters (user_id, name);

CREATE TABLE homebrew_content (
  user_id UUID NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  id TEXT NOT NULL,
  document JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category, id)
);

CREATE TABLE account_settings (
  user_id UUID PRIMARY KEY REFERENCES accounts (id) ON DELETE CASCADE,
  document JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
''',
  ),
  Migration(
    id: '0002_accounts_oidc_and_sessions',
    sql: '''
ALTER TABLE accounts ADD COLUMN oidc_subject TEXT UNIQUE;

-- El token de sesión nunca se guarda en claro: si la base se filtra, no debe
-- entregar sesiones válidas. Se guarda su hash SHA-256 (columna `token_hash`);
-- la cookie del navegador lleva el token, no el hash.
CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sessions_user_id_idx ON sessions (user_id);
''',
  ),
  Migration(
    id: '0003_sessions_expires_at_idx',
    sql: '''
-- `PostgresSessionStore.deleteExpired` barre por `expires_at` en cada login. Sin este
-- índice ese barrido es un recorrido completo de la tabla, que es justo el
-- caso que importa: la tabla se limpia por primera vez cuando ya venía
-- creciendo sin freno.
CREATE INDEX sessions_expires_at_idx ON sessions (expires_at);
''',
  ),
  Migration(
    id: '0004_sessions_profile',
    sql: '''
-- Caché de lo que el proveedor OIDC afirmó al abrir esta sesión: sirve para
-- mostrar en pantalla con qué cuenta se entró. El dueño del dato sigue siendo
-- el proveedor; acá vence junto con la sesión que lo produjo.
--
-- Todas nullable: las sesiones abiertas antes de este despliegue siguen siendo
-- válidas, simplemente no tienen perfil que mostrar.
--
-- `logout_url` ya trae el `id_token_hint`, así que cerrar sesión también cierra
-- la del proveedor. No es una credencial de acceso: no sirve para llamar a
-- ninguna API, solo para terminar esta misma sesión.
ALTER TABLE sessions
  ADD COLUMN display_name TEXT,
  ADD COLUMN email        TEXT,
  ADD COLUMN picture_url  TEXT,
  ADD COLUMN logout_url   TEXT;
''',
  ),
  Migration(
    id: '0005_characters_created_at',
    sql: '''
-- Cuándo entró el personaje a la cuenta, para poder ordenar el roster por
-- antigüedad. No sale del documento: ese lo manda el cliente y no puede fijar
-- su propia fecha de alta. `updated_at` no sirve para esto porque cambia con
-- cada edición.
--
-- Los personajes que ya existían quedan todos con la fecha de la migración: no
-- hay forma de reconstruir cuándo se crearon, y entre ellos el orden por fecha
-- será arbitrario hasta que se creen personajes nuevos.
ALTER TABLE characters
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
''',
  ),
];
