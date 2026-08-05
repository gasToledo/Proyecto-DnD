import 'package:dnd_server/src/config.dart';
import 'package:test/test.dart';

void main() {
  const dbEnv = {
    'DND_DB_PASSWORD': 'secreto',
    'DND_OIDC_ISSUER_URL': 'https://auth.example.com',
    'DND_OIDC_CLIENT_ID': 'dnd-app',
    'DND_OIDC_CLIENT_SECRET': 'oidc-secreto',
    'DND_PUBLIC_BASE_URL': 'https://fichas.example.com',
  };

  group('ServerConfig.fromEnvironment', () {
    test('usa host y puerto por defecto sin variables de entorno', () {
      final config = ServerConfig.fromEnvironment(dbEnv);

      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
    });

    test('respeta las variables de entorno provistas', () {
      final config = ServerConfig.fromEnvironment({
        ...dbEnv,
        'DND_SERVER_HOST': '127.0.0.1',
        'DND_SERVER_PORT': '9090',
      });

      expect(config.host, '127.0.0.1');
      expect(config.port, 9090);
    });

    test('un puerto no numérico falla con un error comprensible', () {
      expect(
        () => ServerConfig.fromEnvironment({
          ...dbEnv,
          'DND_SERVER_PORT': 'no-es-un-numero',
        }),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'sin contraseña de base de datos falla al construir la configuración',
      () {
        expect(
          () => ServerConfig.fromEnvironment(const {}),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('DatabaseConfig.fromEnvironment', () {
    test('usa valores por defecto razonables salvo la contraseña', () {
      final config = DatabaseConfig.fromEnvironment(dbEnv);

      expect(config.host, 'localhost');
      expect(config.port, 5432);
      expect(config.database, 'dnd');
      expect(config.username, 'dnd');
      expect(config.password, 'secreto');
    });

    test('respeta las variables de entorno provistas', () {
      final config = DatabaseConfig.fromEnvironment({
        'DND_DB_HOST': 'db.internal',
        'DND_DB_PORT': '5433',
        'DND_DB_NAME': 'dnd_prod',
        'DND_DB_USER': 'dnd_app',
        'DND_DB_PASSWORD': 'secreto',
      });

      expect(config.host, 'db.internal');
      expect(config.port, 5433);
      expect(config.database, 'dnd_prod');
      expect(config.username, 'dnd_app');
    });
  });

  group('OidcConfig.fromEnvironment', () {
    test('calcula la URI de callback a partir de la base pública', () {
      final config = OidcConfig.fromEnvironment(dbEnv);

      expect(
        config.redirectUri.toString(),
        'https://fichas.example.com/auth/callback',
      );
    });

    test('sin issuer configurado falla al construir', () {
      expect(
        () => OidcConfig.fromEnvironment({
          'DND_OIDC_CLIENT_ID': 'x',
          'DND_OIDC_CLIENT_SECRET': 'x',
          'DND_PUBLIC_BASE_URL': 'https://x.example.com',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('PortraitsConfig.fromEnvironment', () {
    test('usa valores por defecto sin variables de entorno', () {
      final config = PortraitsConfig.fromEnvironment(const {});

      expect(config.root, 'data/portraits');
      expect(config.maxBytes, 8 * 1024 * 1024);
    });

    test('respeta las variables de entorno provistas', () {
      final config = PortraitsConfig.fromEnvironment(const {
        'DND_PORTRAITS_ROOT': '/var/lib/dnd/portraits',
        'DND_PORTRAITS_MAX_BYTES': '1000',
      });

      expect(config.root, '/var/lib/dnd/portraits');
      expect(config.maxBytes, 1000);
    });
  });

  group('AiProvidersConfig.fromEnvironment', () {
    test('sin variables de entorno, ninguna credencial está configurada', () {
      final config = AiProvidersConfig.fromEnvironment(const {});

      expect(config.azureApiKey, isEmpty);
      expect(config.azureOpenAiApiKey, isEmpty);
    });

    test('respeta las credenciales provistas', () {
      final config = AiProvidersConfig.fromEnvironment(const {
        'DND_AZURE_FLUX_API_KEY': 'flux-key',
        'DND_AZURE_OPENAI_API_KEY': 'openai-key',
      });

      expect(config.azureApiKey, 'flux-key');
      expect(config.azureOpenAiApiKey, 'openai-key');
    });
  });

  group('WebConfig.fromEnvironment', () {
    test(
      'sin variable de entorno, el servido estático queda deshabilitado',
      () {
        final config = WebConfig.fromEnvironment(const {});

        expect(config.root, isEmpty);
        expect(config.enabled, isFalse);
      },
    );

    test('con DND_WEB_ROOT, el servido estático queda habilitado', () {
      final config = WebConfig.fromEnvironment(const {
        'DND_WEB_ROOT': '/srv/web',
      });

      expect(config.root, '/srv/web');
      expect(config.enabled, isTrue);
    });
  });

  group('requireEnv', () {
    test('devuelve el valor cuando está presente', () {
      expect(requireEnv({'X': 'valor'}, 'X'), 'valor');
    });

    test('falla con un mensaje que nombra la variable faltante', () {
      expect(
        () => requireEnv(const {}, 'DND_DB_PASSWORD'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            contains('DND_DB_PASSWORD'),
          ),
        ),
      );
    });

    test('un valor vacío se trata como ausente', () {
      expect(
        () => requireEnv(const {'X': ''}, 'X'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
