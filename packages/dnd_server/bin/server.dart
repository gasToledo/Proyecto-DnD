import 'dart:io';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/ai/portrait_provider.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/oidc_service.dart';
import 'package:dnd_server/src/auth/session_store.dart';
import 'package:dnd_server/src/config.dart';
import 'package:dnd_server/src/db/database.dart';
import 'package:dnd_server/src/db/migration_runner.dart';
import 'package:dnd_server/src/import/import_service.dart' as import_service;
import 'package:dnd_server/src/portraits/disk_portrait_blob_store.dart';
import 'package:dnd_server/src/repositories/account_repository.dart';
import 'package:dnd_server/src/repositories/campaign_repository.dart';
import 'package:dnd_server/src/repositories/character_repository.dart';
import 'package:dnd_server/src/repositories/event_repository.dart';
import 'package:dnd_server/src/repositories/homebrew_repository.dart';
import 'package:dnd_server/src/repositories/settings_repository.dart';
import 'package:dnd_server/src/web/cache_headers.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final config = ServerConfig.fromEnvironment(Platform.environment);
  final pool = createPool(config.database);
  await _runMigrationsWithRetry(pool);

  final oidcService = await OidcService.connect(config.oidc);
  final auth = AuthDependencies(
    resolveUserId: (token) => pool.run(
      (session) => PostgresSessionStore(session).userIdForToken(token),
    ),
    beginLogin: oidcService.beginLogin,
    completeLogin: oidcService.completeLogin,
    createSessionForIdentity: (identity) => pool.runTx((session) async {
      final userId = await findOrCreateAccount(session, identity.subject);
      return PostgresSessionStore(session).create(userId, identity: identity);
    }),
    sessionProfile: (token) => pool.run(
      (session) => PostgresSessionStore(session).profileForToken(token),
    ),
    invalidateSession: (token) =>
        pool.run((session) => PostgresSessionStore(session).invalidate(token)),
  );

  final portraits = DiskPortraitBlobStore(
    root: config.portraits.root,
    maxBytes: config.portraits.maxBytes,
  );
  final generation = PortraitGenerationService(
    buildProviders(config.aiProviders),
  );

  final webStaticHandler = _buildWebStaticHandler(config.web);

  final server = await shelf_io.serve(
    buildHandler(
      auth: auth,
      portraits: portraits,
      generation: generation,
      importBackup: ({required userId, required bundle}) =>
          import_service.importBackup(
            pool: pool,
            portraits: portraits,
            userId: userId,
            bundle: bundle,
          ),
      // `Pool` implementa `Session`: alcanza una única instancia de cada
      // repositorio para toda la vida del proceso, sin volver a abrir una
      // sesión por request (cada método de repositorio ya adquiere su propia
      // conexión del pool al ejecutar).
      characters: PostgresCharacterRepository(pool),
      campaigns: PostgresCampaignRepository(pool),
      events: PostgresEventRepository(pool),
      homebrew: PostgresHomebrewRepository(pool),
      settings: PostgresSettingsRepository(pool),
      webStaticHandler: webStaticHandler,
    ),
    config.host,
    config.port,
  );
  // Buena práctica detrás de un proxy inverso (Cloudflare Tunnel): evita que
  // shelf cierre la conexión antes de que el proxy la reutilice.
  server.autoCompress = true;
  print('dnd_server escuchando en ${config.host}:${config.port}');

  Future<void> shutdown() async {
    print('Apagando dnd_server...');
    await server.close(force: false);
    await pool.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => shutdown());
  }
}

/// Corre las migraciones pendientes al arrancar. Si la base todavía no
/// acepta conexiones (por ejemplo, el contenedor de Postgres sigue
/// levantando), reintenta en vez de terminar el proceso: el orden de
/// arranque de los contenedores no está garantizado.
Future<void> _runMigrationsWithRetry(
  Pool pool, {
  int maxAttempts = 10,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final ranNow = await pool.runTx(
        (session) => const MigrationRunner().run(session),
      );
      if (ranNow.isNotEmpty) {
        print('Migraciones aplicadas: ${ranNow.join(', ')}');
      }
      return;
    } catch (error) {
      if (attempt == maxAttempts) rethrow;
      print(
        'La base de datos no está lista (intento $attempt/$maxAttempts): '
        '$error. Reintentando en ${delay.inSeconds}s...',
      );
      await Future<void>.delayed(delay);
    }
  }
}

/// `null` si `config.web` está deshabilitado (sin `DND_WEB_ROOT`): el
/// servidor sigue respondiendo `/api` y `/auth` igual, simplemente no hay
/// build web detrás para el resto de las rutas. Cuando está habilitado, se
/// espera que el directorio ya contenga el resultado de
/// `flutter build web --base-href /` copiado por la imagen del contenedor.
Handler? _buildWebStaticHandler(WebConfig web) {
  if (!web.enabled) return null;
  if (!Directory(web.root).existsSync()) {
    print(
      'DND_WEB_ROOT="${web.root}" no existe: el servidor no servirá el '
      'cliente web.',
    );
    return null;
  }
  final rawHandler = createStaticHandler(
    web.root,
    defaultDocument: 'index.html',
  );
  return const Pipeline()
      .addMiddleware(webCacheHeadersMiddleware)
      .addHandler(rawHandler);
}
