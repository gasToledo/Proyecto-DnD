import 'package:postgres/postgres.dart';

import '../config.dart';

/// Crea el pool de conexiones a la base de la aplicación a partir de la
/// configuración cargada por entorno.
Pool createPool(DatabaseConfig config) {
  return Pool.withEndpoints([
    Endpoint(
      host: config.host,
      port: config.port,
      database: config.database,
      username: config.username,
      password: config.password,
    ),
  ], settings: const PoolSettings(maxConnectionCount: 10));
}
