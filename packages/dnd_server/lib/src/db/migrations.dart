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
  Migration(
    id: '0006_campaigns_and_character_sharing',
    sql: '''
-- Primera vez que una cuenta puede leer algo de otra. Hasta acá cada tabla era
-- de un solo dueño y toda consulta filtraba por `user_id`; lo que sigue abre
-- esa puerta, y la abre únicamente cuando el dueño del personaje la abrió
-- antes con un código generado por él.
CREATE TABLE campaigns (
  dm_user_id UUID NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  document JSONB NOT NULL,
  name TEXT NOT NULL GENERATED ALWAYS AS (document ->> 'name') STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (dm_user_id, id)
);

CREATE INDEX campaigns_dm_user_id_name_idx ON campaigns (dm_user_id, name);

-- El vínculo es una referencia viva, no una copia: guarda a qué personaje
-- apuntar, y la ficha se lee de su fila real en cada consulta. Nunca hay dos
-- versiones del mismo personaje que puedan desalinearse.
--
-- Tiene clave sustituta además de la combinación natural porque el vínculo se
-- corta desde los dos lados: con un id opaco, la URL con la que el jugador
-- deja de compartir no necesita nombrar al DM.
--
-- Las dos rutas de borrado en cascada son intencionales: si se va la cuenta
-- del DM se van sus campañas y con ellas estos vínculos; si el jugador borra
-- su personaje (o su cuenta), el vínculo se va solo y nunca queda una
-- referencia colgada apuntando a una ficha que ya no existe.
CREATE TABLE campaign_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dm_user_id UUID NOT NULL,
  campaign_id TEXT NOT NULL,
  owner_user_id UUID NOT NULL,
  character_id TEXT NOT NULL,
  linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (dm_user_id, campaign_id, owner_user_id, character_id),
  FOREIGN KEY (dm_user_id, campaign_id)
    REFERENCES campaigns (dm_user_id, id) ON DELETE CASCADE,
  FOREIGN KEY (owner_user_id, character_id)
    REFERENCES characters (user_id, id) ON DELETE CASCADE
);

-- Para "¿en qué campañas está este personaje?", que es la pregunta que hace la
-- ficha del jugador. La combinación única de arriba arranca por `dm_user_id`,
-- así que no sirve para buscar por dueño.
CREATE INDEX campaign_members_owner_idx
  ON campaign_members (owner_user_id, character_id);

-- El código nunca se guarda en claro, por la misma razón que el token de
-- sesión (ver `0002`): un volcado de la base no debe entregar accesos válidos.
-- La fila se borra al canjearse, así que un código sirve una sola vez.
CREATE TABLE character_share_codes (
  code_hash TEXT PRIMARY KEY,
  owner_user_id UUID NOT NULL,
  character_id TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (owner_user_id, character_id)
    REFERENCES characters (user_id, id) ON DELETE CASCADE
);

-- El barrido de vencidos corre en el camino de escritura, igual que el de
-- `sessions`: sin este índice sería un recorrido completo de la tabla.
CREATE INDEX character_share_codes_expires_at_idx
  ON character_share_codes (expires_at);

-- Avisos pendientes de ver. Quien ejecuta una acción recibe respuesta en el
-- momento; esta tabla existe para la otra parte, que no estaba mirando cuando
-- pasó. Es genérica a propósito: los avisos de capítulo que vienen después
-- usan esta misma vía.
--
-- No guarda el texto sino qué pasó (`kind` más los datos en `payload`): el
-- mensaje en español lo redacta el cliente, así se puede corregir una
-- redacción sin migrar la base.
CREATE TABLE user_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  seen_at TIMESTAMPTZ
);

-- Índice parcial: la única consulta es "lo que esta cuenta todavía no vio", y
-- los avisos ya vistos no tienen por qué ocupar lugar en él.
CREATE INDEX user_events_pending_idx
  ON user_events (user_id, created_at) WHERE seen_at IS NULL;
''',
  ),
  Migration(
    id: '0007_encounters',
    sql: '''
-- Un combate activo por campaña, y la clave primaria lo garantiza: no hay
-- estado "¿cuál de los dos combates abiertos es el bueno?" que resolver
-- después. El documento entero se reemplaza en cada guardado (orden de
-- iniciativa, ronda, turno, PG de los monstruos) igual que una ficha: no hay
-- rutas finas de "avanzar turno" o "dañar monstruo" que puedan discrepar
-- entre sí.
CREATE TABLE encounters (
  dm_user_id UUID NOT NULL,
  campaign_id TEXT NOT NULL,
  document JSONB NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (dm_user_id, campaign_id),
  FOREIGN KEY (dm_user_id, campaign_id)
    REFERENCES campaigns (dm_user_id, id) ON DELETE CASCADE
);

-- El log de un combate cerrado. Hoy se graba y no se muestra: cuando exista
-- el Cuaderno de campaña se reagrupa por capítulo, y lo jugado hasta entonces
-- no se pierde por no tener todavía dónde mostrarlo.
CREATE TABLE encounter_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dm_user_id UUID NOT NULL,
  campaign_id TEXT NOT NULL,
  document JSONB NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (dm_user_id, campaign_id)
    REFERENCES campaigns (dm_user_id, id) ON DELETE CASCADE
);

CREATE INDEX encounter_logs_campaign_idx
  ON encounter_logs (dm_user_id, campaign_id, ended_at DESC);
''',
  ),
  Migration(
    id: '0008_chapters',
    sql: '''
-- Los tramos en que se divide una campaña. Misma forma que `campaigns` y
-- `encounters`: documento JSONB, y la campaña como dueña vía clave foránea en
-- cascada.
--
-- Tabla propia y no una lista adentro del documento de la campaña: así
-- renombrar una campaña no reescribe todos sus capítulos, y el documento de
-- la campaña no crece sin techo con cada tramo que se juega.
CREATE TABLE chapters (
  dm_user_id UUID NOT NULL,
  campaign_id TEXT NOT NULL,
  id TEXT NOT NULL,
  document JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (dm_user_id, campaign_id, id),
  FOREIGN KEY (dm_user_id, campaign_id)
    REFERENCES campaigns (dm_user_id, id) ON DELETE CASCADE
);

-- Se listan siempre en orden de alta dentro de una campaña, que es el orden en
-- que el DM los planificó.
CREATE INDEX chapters_campaign_idx
  ON chapters (dm_user_id, campaign_id, created_at);
''',
  ),
  Migration(
    id: '0009_notes',
    sql: '''
-- Las notas del Cuaderno de campaña: la mitad que el DM escribe a mano. La
-- otra mitad —los combates cerrados— ya vive en `encounter_logs`, que hasta
-- ahora se grababa sin que nadie la leyera.
--
-- Misma forma que `chapters`, con una clave foránea de más: la nota cuelga de
-- un capítulo, no de la campaña suelta. Borrar el capítulo se lleva sus notas,
-- que es lo que corresponde — el cuaderno es una línea de tiempo **por
-- capítulo** y una nota huérfana no tendría dónde mostrarse.
--
-- Ningún jugador lee una nota: es material del DM, como la descripción de un
-- capítulo. Por eso la tabla no cruza cuentas y filtra por `dm_user_id` como
-- cualquier tabla de un solo dueño.
CREATE TABLE notes (
  dm_user_id UUID NOT NULL,
  campaign_id TEXT NOT NULL,
  chapter_id TEXT NOT NULL,
  id TEXT NOT NULL,
  document JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (dm_user_id, campaign_id, id),
  FOREIGN KEY (dm_user_id, campaign_id, chapter_id)
    REFERENCES chapters (dm_user_id, campaign_id, id) ON DELETE CASCADE
);

-- Se listan por capítulo y, dentro de él, de la más vieja a la más nueva: el
-- cuaderno se lee como un diario.
CREATE INDEX notes_chapter_idx
  ON notes (dm_user_id, campaign_id, chapter_id, created_at);

-- Un combate cerrado también cuelga de un capítulo, porque el cuaderno es una
-- línea de tiempo por capítulo. Lo resuelve el servidor al archivar, mirando
-- cuál estaba en marcha: el cliente del DM no tiene por qué saberlo.
--
-- Es nullable y **sin** clave foránea, a diferencia de `notes`, por dos
-- motivos distintos: los combates archivados antes de esta migración no tienen
-- capítulo que declarar, y borrar un capítulo no puede borrar el registro de
-- que ese combate se jugó. Una nota es un borrador y se va con su capítulo; un
-- combate pasó, y eso no se deshace.
ALTER TABLE encounter_logs ADD COLUMN chapter_id TEXT;
''',
  ),
];
