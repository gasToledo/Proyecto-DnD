/// Lee una variable de entorno obligatoria. Pensada para secretos y datos de
/// conexión: no existe un valor por defecto razonable para una contraseña de
/// base de datos o una clave de proveedor, así que la ausencia debe frenar el
/// arranque con un mensaje claro en vez de arrancar con un valor inventado.
String requireEnv(Map<String, String> env, String name) {
  final value = env[name];
  if (value == null || value.isEmpty) {
    throw StateError(
      'Falta la variable de entorno "$name", requerida para arrancar el '
      'servidor.',
    );
  }
  return value;
}

/// Lee una variable de entorno opcional con un valor por defecto que **no**
/// puede ser un secreto (puerto, host, tamaños límite, etc.).
String envOr(Map<String, String> env, String name, String fallback) =>
    env[name] ?? fallback;

int envIntOr(Map<String, String> env, String name, int fallback) {
  final raw = env[name];
  if (raw == null) return fallback;
  final parsed = int.tryParse(raw);
  if (parsed == null) {
    throw StateError('La variable de entorno "$name" debe ser un entero.');
  }
  return parsed;
}

/// Datos de conexión a la base de la aplicación (no la de Zitadel, que tiene
/// la suya propia). La contraseña SHALL venir de una variable de entorno o
/// secreto montado: no hay valor por defecto que la sustituya.
class DatabaseConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  factory DatabaseConfig.fromEnvironment(Map<String, String> env) {
    return DatabaseConfig(
      host: envOr(env, 'DND_DB_HOST', 'localhost'),
      port: envIntOr(env, 'DND_DB_PORT', 5432),
      database: envOr(env, 'DND_DB_NAME', 'dnd'),
      username: envOr(env, 'DND_DB_USER', 'dnd'),
      password: requireEnv(env, 'DND_DB_PASSWORD'),
    );
  }
}

/// Datos del proveedor OIDC autoalojado (Zitadel) y de la aplicación
/// registrada en él. `issuerUrl` MUST coincidir exactamente con el nombre
/// público configurado en el proveedor: si difiere, el descubrimiento OIDC
/// falla (ver capacidad `self-hosted-deployment`).
class OidcConfig {
  final Uri issuerUrl;
  final String clientId;
  final String clientSecret;

  /// Base pública de la API (sin barra final), usada para construir la URI
  /// de callback (`$publicBaseUrl/auth/callback`) que se registra en Zitadel.
  final Uri publicBaseUrl;

  const OidcConfig({
    required this.issuerUrl,
    required this.clientId,
    required this.clientSecret,
    required this.publicBaseUrl,
  });

  Uri get redirectUri =>
      publicBaseUrl.replace(path: '${publicBaseUrl.path}/auth/callback');

  factory OidcConfig.fromEnvironment(Map<String, String> env) {
    return OidcConfig(
      issuerUrl: Uri.parse(requireEnv(env, 'DND_OIDC_ISSUER_URL')),
      clientId: requireEnv(env, 'DND_OIDC_CLIENT_ID'),
      clientSecret: requireEnv(env, 'DND_OIDC_CLIENT_SECRET'),
      publicBaseUrl: Uri.parse(requireEnv(env, 'DND_PUBLIC_BASE_URL')),
    );
  }
}

/// Ubicación en disco del volumen de retratos y límite de tamaño admitido.
/// Ninguno de los dos es un secreto, así que ambos tienen valor por defecto.
class PortraitsConfig {
  final String root;
  final int maxBytes;

  const PortraitsConfig({required this.root, required this.maxBytes});

  factory PortraitsConfig.fromEnvironment(Map<String, String> env) {
    return PortraitsConfig(
      root: envOr(env, 'DND_PORTRAITS_ROOT', 'data/portraits'),
      maxBytes: envIntOr(env, 'DND_PORTRAITS_MAX_BYTES', 8 * 1024 * 1024),
    );
  }
}

/// Credenciales de los proveedores de generación de imágenes. A diferencia de
/// [requireEnv], acá una ausencia SHALL degradar en vez de frenar el arranque:
/// un despliegue sin Azure configurado sigue sirviendo Pollinations y la
/// subida de retratos propios (ver capacidad `ai-portrait-generation`). Una
/// cadena vacía significa "no configurado", nunca una credencial real.
class AiProvidersConfig {
  final String azureApiKey;
  final String azureOpenAiApiKey;

  const AiProvidersConfig({
    required this.azureApiKey,
    required this.azureOpenAiApiKey,
  });

  factory AiProvidersConfig.fromEnvironment(Map<String, String> env) {
    return AiProvidersConfig(
      azureApiKey: envOr(env, 'DND_AZURE_FLUX_API_KEY', ''),
      azureOpenAiApiKey: envOr(env, 'DND_AZURE_OPENAI_API_KEY', ''),
    );
  }
}

/// Raíz del build web estático (`flutter build web`) que este mismo proceso
/// sirve en el mismo origen que la API (ver capacidad `self-hosted-deployment`
/// y decisión D5 de `design.md`: el cliente nunca guarda tokens, así que las
/// peticiones a `/api` y a los archivos estáticos comparten cookie de
/// sesión). Una cadena vacía SHALL deshabilitar el servido estático: es el
/// caso de las pruebas y de correr el servidor suelto en desarrollo, no un
/// error.
class WebConfig {
  final String root;

  const WebConfig({required this.root});

  bool get enabled => root.isNotEmpty;

  factory WebConfig.fromEnvironment(Map<String, String> env) {
    return WebConfig(root: envOr(env, 'DND_WEB_ROOT', ''));
  }
}

/// Configuración de arranque del servidor. Cada sección de la migración que
/// agregue una dependencia con secretos (proveedores de IA) suma sus propios
/// campos acá, siempre vía [requireEnv].
class ServerConfig {
  final String host;
  final int port;
  final DatabaseConfig database;
  final OidcConfig oidc;
  final PortraitsConfig portraits;
  final AiProvidersConfig aiProviders;
  final WebConfig web;

  const ServerConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.oidc,
    required this.portraits,
    required this.aiProviders,
    required this.web,
  });

  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    return ServerConfig(
      host: envOr(env, 'DND_SERVER_HOST', '0.0.0.0'),
      port: envIntOr(env, 'DND_SERVER_PORT', 8080),
      database: DatabaseConfig.fromEnvironment(env),
      oidc: OidcConfig.fromEnvironment(env),
      portraits: PortraitsConfig.fromEnvironment(env),
      aiProviders: AiProvidersConfig.fromEnvironment(env),
      web: WebConfig.fromEnvironment(env),
    );
  }
}
