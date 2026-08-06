import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/oidc_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/ai/portrait_provider.dart';
import 'package:dnd_server/src/import/import_service.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/fake_portrait_provider.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_settings_repository.dart';

void main() {
  late FakeAuthDependencies fakeAuth;
  late InMemoryPortraitBlobStore portraits;
  late PortraitGenerationService generation;
  late ImportBackupFn importBackup;
  late InMemoryCharacterRepository characters;
  late InMemoryHomebrewRepository homebrewRepo;
  late InMemorySettingsRepository settingsRepo;
  late Handler handler;

  setUp(() {
    fakeAuth = FakeAuthDependencies();
    portraits = InMemoryPortraitBlobStore();
    generation = PortraitGenerationService([
      FakePortraitProvider(id: 'pollinations', name: 'Pollinations'),
    ]);
    importBackup = ({required userId, required bundle}) async =>
        const ImportResult(charactersImported: 0, portraitsImported: 0);
    characters = InMemoryCharacterRepository();
    homebrewRepo = InMemoryHomebrewRepository();
    settingsRepo = InMemorySettingsRepository();
    handler = buildHandler(
      auth: fakeAuth.dependencies,
      portraits: portraits,
      generation: generation,
      importBackup: importBackup,
      characters: characters,
      homebrew: homebrewRepo,
      settings: settingsRepo,
    );
  });

  group('/health', () {
    test('responde 200 con estado ok', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/health')),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['status'], 'ok');
    });
  });

  test('una ruta desconocida responde 404', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/no-existe')),
    );

    expect(response.statusCode, 404);
  });

  test(
    'un error no manejado se convierte en 500 sin filtrar detalles',
    () async {
      final failing = const Pipeline()
          .addMiddleware(errorHandlingMiddleware)
          .addHandler((request) => throw StateError('boom'));
      final response = await failing(
        Request('GET', Uri.parse('http://localhost/x')),
      );

      expect(response.statusCode, 500);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], isNot(contains('boom')));
    },
  );

  test('un FormatException se convierte en 400 con su mensaje', () async {
    final failing = const Pipeline()
        .addMiddleware(errorHandlingMiddleware)
        .addHandler((request) => throw const FormatException('dato inválido'));
    final response = await failing(
      Request('GET', Uri.parse('http://localhost/x')),
    );

    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString());
    expect(body['error'], 'dato inválido');
  });

  group('autenticación', () {
    test('/auth/login redirige a la URI del proveedor OIDC', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/auth/login')),
      );

      expect(response.statusCode, 302);
      expect(response.headers['location'], contains('idp.example'));
    });

    test('/api/me sin cookie de sesión responde 401', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/me')),
      );

      expect(response.statusCode, 401);
    });

    test('/api/me con una cookie inválida también responde 401', () async {
      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=no-existe'},
        ),
      );

      expect(response.statusCode, 401);
    });

    test('un callback exitoso abre sesión y /api/me la reconoce', () async {
      fakeAuth.nextVerifiedSubject = 'oidc-subject-a';

      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
        ),
      );

      expect(callback.statusCode, 302);
      final setCookie = callback.headers['set-cookie']!;
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('Secure'));
      expect(setCookie, contains('SameSite=Lax'));
      final token = RegExp(
        r'dnd_session=([^;]+)',
      ).firstMatch(setCookie)!.group(1)!;

      final me = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      expect(me.statusCode, 200);
      final body = jsonDecode(await me.readAsString());
      expect(body['userId'], isNotEmpty);
    });

    // Sin esto la pantalla no puede decir con qué cuenta entraste: hasta
    // ahora `/api/me` devolvía solo el id interno, que no le dice nada a nadie.
    test('/api/me devuelve el perfil que afirmó el proveedor', () async {
      fakeAuth.nextVerifiedIdentity = const OidcIdentity(
        subject: 'oidc-subject-perfil',
        name: 'Ada Lovelace',
        email: 'ada@example.org',
        pictureUrl: 'https://idp.example/ada.png',
      );
      final token = await _login(handler);

      final me = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      final body = jsonDecode(await me.readAsString());
      expect(body['name'], 'Ada Lovelace');
      expect(body['email'], 'ada@example.org');
      expect(body['pictureUrl'], 'https://idp.example/ada.png');
    });

    // Una cuenta del proveedor sin nombre ni correo cargados no puede romper
    // el arranque de la aplicación.
    test('/api/me tolera una sesión sin perfil', () async {
      fakeAuth.nextVerifiedIdentity = const OidcIdentity(
        subject: 'oidc-subject-sin-perfil',
      );
      final token = await _login(handler);

      final me = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(me.statusCode, 200);
      final body = jsonDecode(await me.readAsString());
      expect(body['userId'], isNotEmpty);
      expect(body['name'], isNull);
      expect(body['email'], isNull);
    });

    test('la respuesta del callback no expone tokens en el cuerpo: solo '
        'redirección y cookie', () async {
      fakeAuth.nextVerifiedSubject = 'oidc-subject-c';

      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
        ),
      );

      final body = await callback.readAsString();
      expect(body, isEmpty);
      expect(callback.headers.containsKey('set-cookie'), isTrue);
    });

    test('una aserción con emisor o firma inválidos no abre sesión', () async {
      fakeAuth.failCompleteLoginWith = StateError('firma inválida');

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
        ),
      );

      expect(response.statusCode, 401);
      expect(response.headers.containsKey('set-cookie'), isFalse);
    });

    test(
      'cerrar sesión invalida el token y una petición posterior es 401',
      () async {
        fakeAuth.nextVerifiedSubject = 'oidc-subject-b';
        final callback = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
          ),
        );
        final setCookie = callback.headers['set-cookie']!;
        final token = RegExp(
          r'dnd_session=([^;]+)',
        ).firstMatch(setCookie)!.group(1)!;

        final logout = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/logout'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );
        expect(logout.headers['set-cookie'], contains('Max-Age=0'));

        final me = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );
        expect(me.statusCode, 401);
      },
    );

    // Cerrar solo la sesión local deja viva la cookie de SSO del proveedor: el
    // siguiente login vuelve a entrar sin pedir credenciales y el botón parece
    // no haber hecho nada. El cliente necesita esta URL para cerrar las dos.
    test('cerrar sesión devuelve la URL de cierre del proveedor', () async {
      fakeAuth.nextVerifiedIdentity = const OidcIdentity(
        subject: 'oidc-subject-logout',
        logoutUrl: 'https://idp.example/end_session?id_token_hint=abc',
      );
      final token = await _login(handler);

      final logout = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/auth/logout'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      final body = jsonDecode(await logout.readAsString());
      expect(
        body['logoutUrl'],
        'https://idp.example/end_session?id_token_hint=abc',
      );
    });

    // Cerrar dos veces, o sin sesión, sigue sin ser un error: la sesión local
    // ya está cerrada, simplemente no hay a dónde redirigir.
    test('cerrar sesión sin sesión responde 200 con logoutUrl null', () async {
      final logout = await handler(
        Request('POST', Uri.parse('http://localhost/auth/logout')),
      );

      expect(logout.statusCode, 200);
      expect(logout.headers['set-cookie'], contains('Max-Age=0'));
      expect(jsonDecode(await logout.readAsString())['logoutUrl'], isNull);
    });

    test('dos cuentas distintas reciben sesiones que no se mezclan', () async {
      fakeAuth.nextVerifiedSubject = 'subject-a';
      final tokenA = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      fakeAuth.nextVerifiedSubject = 'subject-b';
      final tokenB = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=2&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      final meA = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$tokenA'},
          ),
        )).readAsString(),
      );
      final meB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );

      expect(meA['userId'], isNot(meB['userId']));
    });
  });

  group('/api/portraits', () {
    const pngBytes = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      1, 2, 3, 4,
    ];

    Future<String> _loginAs(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin cookie de sesión no se entrega la imagen', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/portraits/sagan/1.png')),
      );

      expect(response.statusCode, 401);
    });

    test('la propia cuenta recibe el retrato que guardó', () async {
      final token = await _loginAs('subject-owner');
      final me = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      final key = await portraits.save(
        userId: me['userId'] as String,
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/$key'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      expect(await response.read().expand((e) => e).toList(), pngBytes);
    });

    test(
      'un retrato de otra cuenta responde como inexistente, no 403',
      () async {
        final ownerToken = await _loginAs('subject-owner-2');
        final ownerMe = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/me'),
              headers: {'cookie': 'dnd_session=$ownerToken'},
            ),
          )).readAsString(),
        );
        final key = await portraits.save(
          userId: ownerMe['userId'] as String,
          characterId: 'sagan',
          bytes: Uint8List.fromList(pngBytes),
        );

        final intruderToken = await _loginAs('subject-intruder');
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/portraits/$key'),
            headers: {'cookie': 'dnd_session=$intruderToken'},
          ),
        );

        expect(response.statusCode, 404);
      },
    );

    test('un retrato inexistente también responde 404', () async {
      final token = await _loginAs('subject-empty');

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/sagan/no-existe.png'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 404);
    });
  });

  group('/api/portraits/providers', () {
    test('sin sesión no se entrega', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/portraits/providers')),
      );

      expect(response.statusCode, 401);
    });

    test('lista solo los proveedores configurados', () async {
      fakeAuth.nextVerifiedSubject = 'subject-providers';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/providers'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['providers'], [
        {
          'id': 'pollinations',
          'name': 'Pollinations',
          'supportsReference': false,
        },
      ]);
    });
  });

  group('/api/portraits/generate', () {
    Future<String> _login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión no se genera nada', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/portraits/generate'),
          body: jsonEncode({'providerId': 'pollinations', 'prompt': 'x'}),
        ),
      );

      expect(response.statusCode, 401);
    });

    test('un proveedor desconocido responde 400', () async {
      final token = await _login('subject-gen-1');

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/portraits/generate'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'providerId': 'no-existe', 'prompt': 'x'}),
        ),
      );

      expect(response.statusCode, 400);
    });

    test('genera y devuelve las imágenes en base64, nunca una key', () async {
      final token = await _login('subject-gen-2');

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/portraits/generate'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'providerId': 'pollinations',
            'prompt': 'un caballero',
          }),
        ),
      );

      expect(response.statusCode, 200);
      final body = await response.readAsString();
      expect(body, isNot(contains('apiKey')));
      final decoded = jsonDecode(body);
      expect(decoded['images'], hasLength(1));
    });

    test(
      'un fallo del proveedor responde 502 con un mensaje, no un 500',
      () async {
        generation = PortraitGenerationService([
          FakePortraitProvider(
            id: 'pollinations',
            onGenerate: ({required prompt, reference, count}) async =>
                throw ProviderException('el proveedor rechazó el pedido'),
          ),
        ]);
        handler = buildHandler(
          auth: fakeAuth.dependencies,
          portraits: portraits,
          generation: generation,
          importBackup: importBackup,
          characters: characters,
          homebrew: homebrewRepo,
          settings: settingsRepo,
        );
        final token = await _login('subject-gen-3');

        final response = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/portraits/generate'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode({'providerId': 'pollinations', 'prompt': 'x'}),
          ),
        );

        expect(response.statusCode, 502);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], 'el proveedor rechazó el pedido');
      },
    );
  });

  group('POST /api/characters/<id>/portraits', () {
    test('sin sesión no se guarda nada', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters/sagan/portraits'),
          body: jsonEncode({'bytes': 'ab'}),
        ),
      );

      expect(response.statusCode, 401);
    });

    test('guarda los bytes elegidos y devuelve la clave', () async {
      fakeAuth.nextVerifiedSubject = 'subject-upload';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      const pngBase64 =
          'iVBORw0KGgo='; // cabecera PNG suficiente para sniffPortraitImageType

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters/sagan/portraits'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'bytes': pngBase64}),
        ),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['key'], startsWith('sagan/'));
    });

    test('la subida de un retrato propio funciona aunque no haya proveedores '
        'de IA configurados', () async {
      generation = PortraitGenerationService(const []);
      handler = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        characters: characters,
        homebrew: homebrewRepo,
        settings: settingsRepo,
      );
      fakeAuth.nextVerifiedSubject = 'subject-upload-no-providers';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters/sagan/portraits'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'bytes': 'iVBORw0KGgo='}),
        ),
      );

      expect(response.statusCode, 200);
    });
  });

  group('POST /api/import', () {
    test('sin sesión no se importa nada', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          body: jsonEncode({'bytes': 'ab'}),
        ),
      );

      expect(response.statusCode, 401);
    });

    test('un ZIP inválido responde 400 sin invocar la importación', () async {
      fakeAuth.nextVerifiedSubject = 'subject-import-1';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      var called = false;
      handler = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: ({required userId, required bundle}) async {
          called = true;
          return const ImportResult(
            charactersImported: 0,
            portraitsImported: 0,
          );
        },
        characters: characters,
        homebrew: homebrewRepo,
        settings: settingsRepo,
      );

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'bytes': base64Encode(utf8.encode('no es un zip')),
          }),
        ),
      );

      expect(response.statusCode, 400);
      expect(called, isFalse);
    });

    test('un respaldo válido se importa y devuelve el resumen', () async {
      fakeAuth.nextVerifiedSubject = 'subject-import-2';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      handler = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: ({required userId, required bundle}) async {
          expect(bundle.characters.single.character.id, 'sagan');
          return const ImportResult(
            charactersImported: 1,
            portraitsImported: 0,
          );
        },
        characters: characters,
        homebrew: homebrewRepo,
        settings: settingsRepo,
      );

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'bytes': base64Encode(_validZipBytes())}),
        ),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['charactersImported'], 1);
      expect(body['portraitsImported'], 0);
    });
  });

  group('/api/characters', () {
    Map<String, dynamic> characterJson(String id, {String name = 'Sagan'}) => {
      'id': id,
      'name': name,
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': <String, dynamic>{},
    };

    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/characters')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/characters/sagan'),
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
        Request('DELETE', Uri.parse('http://localhost/api/characters/sagan')),
      ]) {
        expect((await handler(request)).statusCode, 401);
      }
    });

    test('crea un personaje y lo devuelve en el listado', () async {
      final token = await login('subject-chars-1');

      final created = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );
      expect(created.statusCode, 200);
      final createdBody = jsonDecode(await created.readAsString());
      expect(createdBody['character']['id'], 'sagan');

      final listed = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      final listedBody = jsonDecode(await listed.readAsString());
      expect(listedBody['characters'], hasLength(1));
      expect(listedBody['characters'][0]['character']['id'], 'sagan');
    });

    test('crear con un id ya usado en la cuenta asigna uno libre en vez de '
        'sobrescribir', () async {
      final token = await login('subject-chars-2');
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': characterJson('sagan', name: 'Original'),
          }),
        ),
      );

      final second = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': characterJson('sagan', name: 'Duplicado'),
          }),
        ),
      );
      final secondBody = jsonDecode(await second.readAsString());
      expect(secondBody['character']['id'], isNot('sagan'));

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['characters'], hasLength(2));
    });

    test('el listado de una cuenta no incluye personajes de otra', () async {
      final tokenA = await login('subject-chars-a');
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$tokenA'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );

      final tokenB = await login('subject-chars-b');
      final listedB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );
      expect(listedB['characters'], isEmpty);
    });

    test('actualiza un personaje existente sin reasignar id', () async {
      final token = await login('subject-chars-3');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/characters/sagan'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': characterJson('sagan', name: 'Actualizado'),
          }),
        ),
      );

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['characters'], hasLength(1));
      expect(listed['characters'][0]['character']['name'], 'Actualizado');
    });

    test(
      'un id de ruta que no coincide con el del cuerpo responde 400',
      () async {
        final token = await login('subject-chars-4');
        final response = await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/characters/otro-id'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode({'character': characterJson('sagan')}),
          ),
        );
        expect(response.statusCode, 400);
      },
    );

    test('un documento sin los campos requeridos responde 400', () async {
      final token = await login('subject-chars-5');
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': {'id': 'sagan'},
          }),
        ),
      );
      expect(response.statusCode, 400);
    });

    test('una versión de esquema futura responde 400', () async {
      final token = await login('subject-chars-6');
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': {...characterJson('sagan'), 'schemaVersion': 999},
          }),
        ),
      );
      expect(response.statusCode, 400);
    });

    test('borra un personaje de la cuenta', () async {
      final token = await login('subject-chars-7');
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );

      final deleted = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/characters/sagan'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      expect(deleted.statusCode, 200);

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['characters'], isEmpty);
    });

    test(
      'borrar con el id de un personaje de otra cuenta no lo afecta',
      () async {
        final tokenB = await login('subject-chars-8b');
        await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$tokenB'},
            body: jsonEncode({
              'character': characterJson('sagan', name: 'De B'),
            }),
          ),
        );

        final tokenA = await login('subject-chars-8a');
        final deleted = await handler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/characters/sagan'),
            headers: {'cookie': 'dnd_session=$tokenA'},
          ),
        );
        // No hay "sagan" en la cuenta de quien pide el borrado: responde 200
        // igual (borrar algo que ya no está no es un error, ver
        // `_deleteCharacterHandler`), sin tocar el de la cuenta B.
        expect(deleted.statusCode, 200);

        final listedB = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/characters'),
              headers: {'cookie': 'dnd_session=$tokenB'},
            ),
          )).readAsString(),
        );
        expect(listedB['characters'], hasLength(1));
        expect(listedB['characters'][0]['character']['name'], 'De B');
      },
    );

    test(
      'actualizar con el id de un personaje de otra cuenta no lo sobrescribe: '
      'crea el propio',
      () async {
        final tokenB = await login('subject-chars-9b');
        await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$tokenB'},
            body: jsonEncode({
              'character': characterJson('sagan', name: 'De B'),
            }),
          ),
        );

        final tokenA = await login('subject-chars-9a');
        final updated = await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/characters/sagan'),
            headers: {'cookie': 'dnd_session=$tokenA'},
            body: jsonEncode({
              'character': characterJson('sagan', name: 'Intento de A'),
            }),
          ),
        );
        // La clave primaria es (userId, id): un PUT con el id de otra cuenta
        // no la alcanza, crea (o actualiza) el propio documento de A con ese
        // mismo id, sin escribir nunca la fila de B.
        expect(updated.statusCode, 200);

        final listedB = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/characters'),
              headers: {'cookie': 'dnd_session=$tokenB'},
            ),
          )).readAsString(),
        );
        expect(listedB['characters'], hasLength(1));
        expect(listedB['characters'][0]['character']['name'], 'De B');

        final listedA = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/characters'),
              headers: {'cookie': 'dnd_session=$tokenA'},
            ),
          )).readAsString(),
        );
        expect(listedA['characters'], hasLength(1));
        expect(listedA['characters'][0]['character']['name'], 'Intento de A');
      },
    );
  });

  group('/api/homebrew', () {
    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/homebrew')),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          body: jsonEncode({'id': 'w1'}),
        ),
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
        ),
      ]) {
        expect((await handler(request)).statusCode, 401);
      }
    });

    test('guarda una entidad y aparece agrupada por categoría', () async {
      final token = await login('subject-hb-1');
      final saved = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'id': 'w1', 'name': 'Espada casera'}),
        ),
      );
      expect(saved.statusCode, 200);

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['content']['weapons'], [
        {'id': 'w1', 'name': 'Espada casera'},
      ]);
    });

    test('una categoría desconocida responde 400', () async {
      final token = await login('subject-hb-2');
      final response = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/no-existe/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'id': 'w1'}),
        ),
      );
      expect(response.statusCode, 400);
    });

    test(
      'un id de ruta que no coincide con el del cuerpo responde 400',
      () async {
        final token = await login('subject-hb-3');
        final response = await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/homebrew/weapons/w1'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode({'id': 'otro'}),
          ),
        );
        expect(response.statusCode, 400);
      },
    );

    test('borra una entidad de la cuenta', () async {
      final token = await login('subject-hb-4');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'id': 'w1'}),
        ),
      );
      await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['content']['weapons'], isEmpty);
    });

    test('el homebrew de una cuenta no aparece en el de otra', () async {
      final tokenA = await login('subject-hb-a');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$tokenA'},
          body: jsonEncode({'id': 'w1'}),
        ),
      );

      final tokenB = await login('subject-hb-b');
      final listedB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );
      expect(listedB['content'], isEmpty);
    });
  });

  group('/api/settings', () {
    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/settings')),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          body: jsonEncode({'imageProvider': 'pollinations'}),
        ),
      ]) {
        expect((await handler(request)).statusCode, 401);
      }
    });

    test('sin ajustes guardados devuelve null', () async {
      final token = await login('subject-settings-1');
      final response = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(response['settings'], isNull);
    });

    test('guarda y relee los ajustes de la cuenta', () async {
      final token = await login('subject-settings-2');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'imageProvider': 'azure'}),
        ),
      );

      final response = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(response['settings'], {'imageProvider': 'azure'});
    });

    test('los ajustes de dos cuentas no se mezclan', () async {
      final tokenA = await login('subject-settings-a');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          headers: {'cookie': 'dnd_session=$tokenA'},
          body: jsonEncode({'imageProvider': 'azure'}),
        ),
      );

      final tokenB = await login('subject-settings-b');
      final responseB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );
      expect(responseB['settings'], isNull);
    });
  });

  group('webStaticHandler', () {
    test('una ruta que el enrutado no reconoce cae al build web', () async {
      final withStatic = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        characters: characters,
        homebrew: homebrewRepo,
        settings: settingsRepo,
        webStaticHandler: (request) =>
            Response.ok('build web', headers: {'x-fuente': 'estatico'}),
      );

      final response = await withStatic(
        Request('GET', Uri.parse('http://localhost/')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['x-fuente'], 'estatico');
    });

    test('una ruta de la API nunca cae al build web', () async {
      final withStatic = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        characters: characters,
        homebrew: homebrewRepo,
        settings: settingsRepo,
        webStaticHandler: (request) =>
            Response.ok('build web', headers: {'x-fuente': 'estatico'}),
      );

      final response = await withStatic(
        Request('GET', Uri.parse('http://localhost/api/characters')),
      );

      expect(response.headers['x-fuente'], isNull);
    });
  });
}

/// Arma un respaldo mínimo válido (un personaje, sin retratos) para probar el
/// enrutado de `/api/import` sin depender de `BackupBundleCodec`, que no se
/// expone fuera de `dnd_server` (la prueba vive del lado de la API, no del
/// codec, que ya tiene su propia batería en `import/backup_bundle_test.dart`).
Uint8List _validZipBytes() {
  final archive = Archive();
  archive.add(
    ArchiveFile.string(
      'characters/sagan.json',
      jsonEncode({
        'id': 'sagan',
        'name': 'Sagan',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': <String, dynamic>{},
      }),
    ),
  );
  archive.add(
    ArchiveFile.string(
      'manifest.json',
      jsonEncode({
        'type': 'dnd_bundle',
        'formatVersion': 2,
        'scope': 'character',
        'characters': [
          {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
        ],
      }),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

String _extractToken(String setCookieHeader) =>
    RegExp(r'dnd_session=([^;]+)').firstMatch(setCookieHeader)!.group(1)!;

/// Recorre el callback con la identidad que el doble tenga configurada y
/// devuelve el token de la cookie resultante.
Future<String> _login(Handler handler) async {
  final callback = await handler(
    Request(
      'GET',
      Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
    ),
  );
  return _extractToken(callback.headers['set-cookie']!);
}
