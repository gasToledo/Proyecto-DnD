import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/oidc_service.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/ai/portrait_provider.dart';
import 'package:dnd_server/src/import/import_service.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/fake_portrait_provider.dart';
import 'fakes/in_memory_campaign_repository.dart';
import 'fakes/in_memory_chapter_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_encounter_repository.dart';
import 'fakes/in_memory_event_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_settings_repository.dart';

void main() {
  late FakeAuthDependencies fakeAuth;
  late InMemoryPortraitBlobStore portraits;
  late PortraitGenerationService generation;
  late ImportBackupFn importBackup;
  late InMemoryCharacterRepository characters;
  late InMemoryCampaignRepository campaigns;
  late InMemoryChapterRepository chapters;
  late InMemoryNoteRepository notes;
  late InMemoryEncounterRepository encounters;
  late InMemoryEventRepository events;
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
    campaigns = InMemoryCampaignRepository(characters);
    chapters = InMemoryChapterRepository(campaigns);
    notes = InMemoryNoteRepository(campaigns, chapters);
    encounters = InMemoryEncounterRepository(campaigns);
    events = InMemoryEventRepository();
    homebrewRepo = InMemoryHomebrewRepository();
    settingsRepo = InMemorySettingsRepository();
    handler = buildHandler(
      auth: fakeAuth.dependencies,
      portraits: portraits,
      generation: generation,
      importBackup: importBackup,
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      notes: notes,
      encounters: encounters,
      events: events,
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

    test('con ?w= devuelve la miniatura de ese ancho', () async {
      // El medallón del roster mide menos de cien píxeles y el original 1024:
      // el cliente pide el ancho en que va a dibujar porque en el navegador no
      // hay forma de decodificar a medida (ver `PortraitImage.provider`).
      final token = await _loginAs('subject-thumb');
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
        bytes: Uint8List.fromList(
          img.encodePng(img.Image(width: 1024, height: 1024)),
        ),
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/$key?w=128'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      final bytes = Uint8List.fromList(
        await response.read().expand((e) => e).toList(),
      );
      expect(img.decodePng(bytes)!.width, 128);
      // Una clave de retrato nunca se reescribe, así que el navegador no tiene
      // por qué volver a pedirla.
      expect(response.headers['cache-control'], contains('immutable'));
    });

    test('un ?w= inservible sirve el original en vez de fallar', () async {
      // Un medallón vacío por un parámetro mal formado sería peor que bajar de
      // más: el retrato tiene que aparecer igual.
      final token = await _loginAs('subject-thumb-bad');
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

      for (final w in ['0', '-8', 'grande', '9999']) {
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/portraits/$key?w=$w'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );

        expect(response.statusCode, 200, reason: 'con w=$w');
        expect(
          await response.read().expand((e) => e).toList(),
          pngBytes,
          reason: 'con w=$w',
        );
      }
    });

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
          campaigns: campaigns,
          chapters: chapters,
          notes: notes,
          encounters: encounters,
          events: events,
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
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
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
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
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
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
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

    test('los objetos son una categoría válida y se pueden borrar', () async {
      final token = await login('subject-hb-items');
      final cookie = {'cookie': 'dnd_session=$token'};

      final saved = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/items/hb-capa'),
          headers: cookie,
          body: jsonEncode({'id': 'hb-capa', 'name': 'Capa de protección'}),
        ),
      );
      expect(saved.statusCode, 200);

      Future<dynamic> listItems() async => jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: cookie,
          ),
        )).readAsString(),
      )['content']['items'];

      expect(await listItems(), [
        {'id': 'hb-capa', 'name': 'Capa de protección'},
      ]);

      final deleted = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/homebrew/items/hb-capa'),
          headers: cookie,
        ),
      );
      expect(deleted.statusCode, 200);
      expect(await listItems(), isEmpty);
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
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
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
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
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

  // Es la única parte del servidor donde una cuenta alcanza datos de otra, así
  // que lo que más importa acá es lo que NO se puede hacer.
  group('/api/campaigns y compartir personajes', () {
    Map<String, dynamic> characterJson(String id, {String name = 'Sagan'}) => {
      'id': id,
      'name': name,
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': <String, dynamic>{},
    };

    Map<String, dynamic> campaignJson(String id, {String name = 'La Tumba'}) =>
        {'id': id, 'name': name};

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

    Future<Map<String, dynamic>> send(
      String method,
      String path, {
      String? token,
      Object? body,
    }) async {
      final response = await handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {if (token != null) 'cookie': 'dnd_session=$token'},
          body: body == null ? null : jsonEncode(body),
        ),
      );
      final text = await response.readAsString();
      return {
        'status': response.statusCode,
        'body': text.isEmpty ? null : jsonDecode(text),
      };
    }

    /// Deja un personaje creado y devuelve un código para compartirlo.
    Future<String> shareCharacter(String token, String characterId) async {
      await send(
        'POST',
        '/api/characters',
        token: token,
        body: {'character': characterJson(characterId)},
      );
      final shared = await send(
        'POST',
        '/api/characters/$characterId/share',
        token: token,
      );
      return shared['body']['code'] as String;
    }

    Future<void> createCampaign(String token, String id) => send(
      'POST',
      '/api/campaigns',
      token: token,
      body: {'campaign': campaignJson(id)},
    );

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/campaigns')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/campaigns'),
          body: jsonEncode({'campaign': campaignJson('c1')}),
        ),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/campaigns/c1'),
          body: jsonEncode({'campaign': campaignJson('c1')}),
        ),
        Request('DELETE', Uri.parse('http://localhost/api/campaigns/c1')),
        Request('GET', Uri.parse('http://localhost/api/campaigns/c1/members')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/campaigns/c1/members'),
          body: jsonEncode({'code': 'ABCD-EFGH'}),
        ),
        Request('POST', Uri.parse('http://localhost/api/characters/x/share')),
        Request('GET', Uri.parse('http://localhost/api/characters/x/shares')),
        Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/campaign-links/'
            '00000000-0000-4000-8000-000000000000',
          ),
        ),
        Request('GET', Uri.parse('http://localhost/api/events')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/events/seen'),
          body: jsonEncode({'ids': <String>[]}),
        ),
      ]) {
        expect(
          (await handler(request)).statusCode,
          401,
          reason: '${request.url}',
        );
      }
    });

    test(
      'el listado de campañas de una cuenta no incluye las de otra',
      () async {
        final tokenA = await login('camp-a');
        await createCampaign(tokenA, 'tumba');

        final tokenB = await login('camp-b');
        final listed = await send('GET', '/api/campaigns', token: tokenB);

        expect(listed['body']['campaigns'], isEmpty);
      },
    );

    test('no se puede editar ni borrar la campaña de otra cuenta', () async {
      final tokenA = await login('camp-edit-a');
      await createCampaign(tokenA, 'tumba');

      final tokenB = await login('camp-edit-b');
      final edited = await send(
        'PUT',
        '/api/campaigns/tumba',
        token: tokenB,
        body: {'campaign': campaignJson('tumba', name: 'Secuestrada')},
      );
      expect(edited['status'], 404);

      await send('DELETE', '/api/campaigns/tumba', token: tokenB);

      final stillThere = await send('GET', '/api/campaigns', token: tokenA);
      expect(stillThere['body']['campaigns'], hasLength(1));
      expect(stillThere['body']['campaigns'][0]['name'], 'La Tumba');
    });

    test(
      'el DM ve la ficha después de canjear el código del jugador',
      () async {
        final tokenA = await login('link-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('link-b');
        await createCampaign(tokenB, 'tumba');
        final redeemed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        expect(redeemed['status'], 200);

        final members = await send(
          'GET',
          '/api/campaigns/tumba/members',
          token: tokenB,
        );
        expect(members['body']['members'], hasLength(1));
        expect(members['body']['members'][0]['character']['id'], 'sagan');
      },
    );

    // El vínculo es una referencia, no una copia: el DM tiene que ver lo que
    // el jugador tiene ahora, no lo que tenía al compartir.
    test(
      'el DM ve los cambios que el jugador hace después de vincular',
      () async {
        final tokenA = await login('live-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('live-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        await send(
          'PUT',
          '/api/characters/sagan',
          token: tokenA,
          body: {'character': characterJson('sagan', name: 'Sagan el Rojo')},
        );

        final members = await send(
          'GET',
          '/api/campaigns/tumba/members',
          token: tokenB,
        );
        expect(
          members['body']['members'][0]['character']['name'],
          'Sagan el Rojo',
        );
      },
    );

    test('un código no se puede canjear dos veces', () async {
      final tokenA = await login('once-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('once-b');
      await createCampaign(tokenB, 'tumba');
      await createCampaign(tokenB, 'otra');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      final second = await send(
        'POST',
        '/api/campaigns/otra/members',
        token: tokenB,
        body: {'code': code},
      );
      expect(second['status'], 404);
    });

    test('un código inventado no sirve y no dice por qué', () async {
      final tokenB = await login('fake-code-b');
      await createCampaign(tokenB, 'tumba');

      final response = await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': 'ZZZZ-ZZZZ'},
      );

      expect(response['status'], 404);
      expect(response['body']['error'], 'Código inválido o vencido.');
    });

    // Intentar contra una campaña ajena no puede costarle el código al jugador:
    // la sentencia se revierte entera y el código sigue sirviendo.
    test(
      'canjear contra una campaña ajena falla y no quema el código',
      () async {
        final tokenA = await login('steal-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenC = await login('steal-c');
        await createCampaign(tokenC, 'ajena');

        final tokenB = await login('steal-b');
        final stolen = await send(
          'POST',
          '/api/campaigns/ajena/members',
          token: tokenB,
          body: {'code': code},
        );
        expect(stolen['status'], 404);

        await createCampaign(tokenB, 'propia');
        final legit = await send(
          'POST',
          '/api/campaigns/propia/members',
          token: tokenB,
          body: {'code': code},
        );
        expect(legit['status'], 200);
      },
    );

    test('sin vínculo, la campaña no muestra ninguna ficha', () async {
      final tokenA = await login('nolink-a');
      await send(
        'POST',
        '/api/characters',
        token: tokenA,
        body: {'character': characterJson('sagan')},
      );

      final tokenB = await login('nolink-b');
      await createCampaign(tokenB, 'tumba');
      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );

      expect(members['body']['members'], isEmpty);
    });

    test(
      'compartir un personaje ajeno responde como si no existiera',
      () async {
        final tokenA = await login('share-a');
        await send(
          'POST',
          '/api/characters',
          token: tokenA,
          body: {'character': characterJson('sagan')},
        );

        final tokenB = await login('share-b');
        final response = await send(
          'POST',
          '/api/characters/sagan/share',
          token: tokenB,
        );

        expect(response['status'], 404);
      },
    );

    test('el jugador ve en qué campañas está su personaje', () async {
      final tokenA = await login('shares-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('shares-b');
      await createCampaign(tokenB, 'tumba');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      final shares = await send(
        'GET',
        '/api/characters/sagan/shares',
        token: tokenA,
      );
      expect(shares['body']['shares'], hasLength(1));
      expect(shares['body']['shares'][0]['campaignName'], 'La Tumba');
      // El id del DM es de uso interno: sirve para avisarle, no para mostrarlo.
      expect(shares['body']['shares'][0].containsKey('dmUserId'), isFalse);
    });

    test('el jugador corta el vínculo y el DM deja de ver la ficha', () async {
      final tokenA = await login('unlink-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('unlink-b');
      await createCampaign(tokenB, 'tumba');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      final shares = await send(
        'GET',
        '/api/characters/sagan/shares',
        token: tokenA,
      );
      final memberId = shares['body']['shares'][0]['memberId'];
      final cut = await send(
        'DELETE',
        '/api/campaign-links/$memberId',
        token: tokenA,
      );
      expect(cut['status'], 200);

      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );
      expect(members['body']['members'], isEmpty);
    });

    test('un tercero no puede cortar un vínculo del que no es parte', () async {
      final tokenA = await login('third-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('third-b');
      await createCampaign(tokenB, 'tumba');
      final redeemed = await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );
      final memberId = redeemed['body']['member']['memberId'];

      final tokenC = await login('third-c');
      final attempt = await send(
        'DELETE',
        '/api/campaign-links/$memberId',
        token: tokenC,
      );
      expect(attempt['status'], 404);

      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );
      expect(members['body']['members'], hasLength(1));
    });

    test('borrar el personaje se lleva el vínculo', () async {
      final tokenA = await login('cascade-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('cascade-b');
      await createCampaign(tokenB, 'tumba');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      await send('DELETE', '/api/characters/sagan', token: tokenA);

      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );
      expect(members['body']['members'], isEmpty);
    });

    group('avisos', () {
      Future<List<dynamic>> pending(String token) async {
        final response = await send('GET', '/api/events', token: token);
        return response['body']['events'] as List<dynamic>;
      }

      test('vincular avisa al jugador y no al DM que lo hizo', () async {
        final tokenA = await login('ev-link-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-link-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        final forPlayer = await pending(tokenA);
        expect(forPlayer, hasLength(1));
        expect(forPlayer[0]['kind'], 'character_linked');
        expect(forPlayer[0]['payload']['characterName'], 'Sagan');
        expect(forPlayer[0]['payload']['campaignName'], 'La Tumba');

        expect(await pending(tokenB), isEmpty);
      });

      test('echar avisa al jugador; irse avisa al DM', () async {
        final tokenA = await login('ev-kick-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-kick-b');
        await createCampaign(tokenB, 'tumba');
        final redeemed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await send(
          'POST',
          '/api/events/seen',
          token: tokenA,
          body: {
            'ids': [for (final e in await pending(tokenA)) e['id']],
          },
        );

        // El DM echa al personaje: se entera el jugador.
        await send(
          'DELETE',
          '/api/campaign-links/${redeemed['body']['member']['memberId']}',
          token: tokenB,
        );
        final afterKick = await pending(tokenA);
        expect(afterKick, hasLength(1));
        expect(afterKick[0]['kind'], 'character_unlinked_by_dm');
        expect(await pending(tokenB), isEmpty);

        // El jugador se va por su cuenta: se entera el DM.
        final code2 = await send(
          'POST',
          '/api/characters/sagan/share',
          token: tokenA,
        );
        final again = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code2['body']['code']},
        );
        await send(
          'DELETE',
          '/api/campaign-links/${again['body']['member']['memberId']}',
          token: tokenA,
        );
        final forDm = await pending(tokenB);
        expect(forDm.last['kind'], 'character_unlinked_by_owner');
      });

      // Sin esto el personaje desaparece del panel del DM sin explicación.
      test('borrar el personaje avisa al DM que lo tenía', () async {
        final tokenA = await login('ev-del-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-del-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        await send('DELETE', '/api/characters/sagan', token: tokenA);

        final forDm = await pending(tokenB);
        expect(forDm, hasLength(1));
        expect(forDm[0]['kind'], 'character_deleted_by_owner');
        expect(forDm[0]['payload']['characterName'], 'Sagan');
      });

      test('un aviso se entrega una sola vez', () async {
        final tokenA = await login('ev-once-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-once-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        final first = await pending(tokenA);
        expect(first, hasLength(1));

        await send(
          'POST',
          '/api/events/seen',
          token: tokenA,
          body: {
            'ids': [first[0]['id']],
          },
        );

        expect(await pending(tokenA), isEmpty);
      });

      test('una cuenta no puede marcar vistos los avisos de otra', () async {
        final tokenA = await login('ev-steal-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-steal-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        final forPlayer = await pending(tokenA);
        final response = await send(
          'POST',
          '/api/events/seen',
          token: tokenB,
          body: {
            'ids': [forPlayer[0]['id']],
          },
        );

        // No falla, pero tampoco hace nada: quien manda un id ajeno no debe
        // poder distinguirlo de uno que no existe.
        expect(response['status'], 200);
        expect(await pending(tokenA), hasLength(1));
      });

      test('un id de aviso mal formado no rompe nada', () async {
        final token = await login('ev-junk');

        final response = await send(
          'POST',
          '/api/events/seen',
          token: token,
          body: {
            'ids': ['no-soy-un-uuid'],
          },
        );

        expect(response['status'], 200);
      });
    });

    group('capítulos', () {
      Map<String, dynamic> chapterJson(
        String id, {
        String name = 'La Cripta',
        String state = 'planned',
        bool grantsLevel = false,
        Object? grantsGold,
        Object? grantsItems,
      }) => {
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'summary': '',
        'state': state,
        'grantsLevel': grantsLevel,
        // Se mandan tal cual llegan, sin tipar: varios casos de acá prueban
        // justamente qué hace el servidor con un botín escrito mal.
        if (grantsGold != null) 'grantsGold': grantsGold,
        if (grantsItems != null) 'grantsItems': grantsItems,
      };

      Future<Map<String, dynamic>> createChapter(
        String token,
        String campaignId,
        String id, {
        String name = 'La Cripta',
        bool grantsLevel = false,
        Object? grantsGold,
        Object? grantsItems,
      }) => send(
        'POST',
        '/api/campaigns/$campaignId/chapters',
        token: token,
        body: {
          'chapter': chapterJson(
            id,
            name: name,
            grantsLevel: grantsLevel,
            grantsGold: grantsGold,
            grantsItems: grantsItems,
          ),
        },
      );

      Future<List<dynamic>> listChapters(
        String token,
        String campaignId,
      ) async {
        final response = await send(
          'GET',
          '/api/campaigns/$campaignId/chapters',
          token: token,
        );
        return response['body']['chapters'] as List<dynamic>;
      }

      test('sin sesión ninguna operación responde 401', () async {
        for (final request in [
          Request(
            'GET',
            Uri.parse('http://localhost/api/campaigns/c1/chapters'),
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/api/campaigns/c1/chapters'),
            body: jsonEncode({'chapter': chapterJson('ch1')}),
          ),
          Request(
            'PUT',
            Uri.parse('http://localhost/api/campaigns/c1/chapters/ch1'),
            body: jsonEncode({'chapter': chapterJson('ch1')}),
          ),
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/campaigns/c1/chapters/ch1'),
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/api/campaigns/c1/chapters/ch1/close'),
          ),
        ]) {
          expect(
            (await handler(request)).statusCode,
            401,
            reason: '${request.url}',
          );
        }
      });

      test('crear, listar y editar un capítulo', () async {
        final token = await login('ch-crud');
        await createCampaign(token, 'tumba');

        final created = await createChapter(token, 'tumba', 'cripta');
        expect(created['status'], 200);
        expect(created['body']['chapter']['name'], 'La Cripta');

        expect(await listChapters(token, 'tumba'), hasLength(1));

        final edited = await send(
          'PUT',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
          body: {'chapter': chapterJson('cripta', name: 'La Cripta Profunda')},
        );
        expect(edited['status'], 200);
        expect(
          (await listChapters(token, 'tumba'))[0]['name'],
          'La Cripta Profunda',
        );
      });

      test('borrar un capítulo lo saca de la lista', () async {
        final token = await login('ch-delete');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');

        await send(
          'DELETE',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
        );

        expect(await listChapters(token, 'tumba'), isEmpty);
      });

      test(
        'los capítulos de una campaña ajena no se ven ni se tocan',
        () async {
          final tokenA = await login('ch-owner');
          await createCampaign(tokenA, 'tumba');
          await createChapter(tokenA, 'tumba', 'cripta');

          final tokenB = await login('ch-intruder');
          expect(
            (await send(
              'GET',
              '/api/campaigns/tumba/chapters',
              token: tokenB,
            ))['status'],
            404,
          );
          expect(
            (await send(
              'POST',
              '/api/campaigns/tumba/chapters',
              token: tokenB,
              body: {'chapter': chapterJson('robado')},
            ))['status'],
            404,
          );
          expect(
            (await send(
              'PUT',
              '/api/campaigns/tumba/chapters/cripta',
              token: tokenB,
              body: {'chapter': chapterJson('cripta', name: 'Secuestrado')},
            ))['status'],
            404,
          );
          expect(
            (await send(
              'DELETE',
              '/api/campaigns/tumba/chapters/cripta',
              token: tokenB,
            ))['status'],
            404,
          );
          expect(
            (await send(
              'POST',
              '/api/campaigns/tumba/chapters/cripta/close',
              token: tokenB,
            ))['status'],
            404,
          );

          // Y lo del dueño quedó intacto.
          expect((await listChapters(tokenA, 'tumba'))[0]['name'], 'La Cripta');
        },
      );

      // Cerrar avisa a otras cuentas: si viajara por el PUT, un reguardado
      // idempotente repetiría los avisos.
      test('un PUT no puede cerrar un capítulo', () async {
        final token = await login('ch-put-close');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');

        final response = await send(
          'PUT',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
          body: {'chapter': chapterJson('cripta', state: 'completed')},
        );

        expect(response['status'], 400);
        expect(response['body']['error'], contains('su propia acción'));
        expect((await listChapters(token, 'tumba'))[0]['state'], 'planned');
      });

      test('no se pueden poner dos capítulos en marcha', () async {
        final token = await login('ch-two-active');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');
        await createChapter(token, 'tumba', 'regreso', name: 'El Regreso');

        await send(
          'PUT',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
          body: {'chapter': chapterJson('cripta', state: 'active')},
        );

        final second = await send(
          'PUT',
          '/api/campaigns/tumba/chapters/regreso',
          token: token,
          body: {
            'chapter': chapterJson(
              'regreso',
              name: 'El Regreso',
              state: 'active',
            ),
          },
        );

        expect(second['status'], 400);
        expect(second['body']['error'], contains('La Cripta'));
      });

      // Reguardar el que ya está en marcha (para corregirle el nombre) no
      // puede chocar contra sí mismo.
      test(
        'editar el capítulo en marcha sin sacarlo de marcha funciona',
        () async {
          final token = await login('ch-edit-active');
          await createCampaign(token, 'tumba');
          await createChapter(token, 'tumba', 'cripta');
          await send(
            'PUT',
            '/api/campaigns/tumba/chapters/cripta',
            token: token,
            body: {'chapter': chapterJson('cripta', state: 'active')},
          );

          final again = await send(
            'PUT',
            '/api/campaigns/tumba/chapters/cripta',
            token: token,
            body: {
              'chapter': chapterJson(
                'cripta',
                name: 'La Cripta Profunda',
                state: 'active',
              ),
            },
          );

          expect(again['status'], 200);
        },
      );

      test('cerrar un capítulo lo completa y avisa a cada jugador', () async {
        final tokenA = await login('ch-close-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(tokenB, 'tumba', 'cripta', grantsLevel: true);
        // El aviso de haberse vinculado ya llegó; se limpia para mirar solo el
        // del capítulo.
        await send(
          'POST',
          '/api/events/seen',
          token: tokenA,
          body: {
            'ids': [
              for (final e
                  in (await send(
                        'GET',
                        '/api/events',
                        token: tokenA,
                      ))['body']['events']
                      as List)
                e['id'],
            ],
          },
        );

        final closed = await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );
        expect(closed['status'], 200);
        expect((await listChapters(tokenB, 'tumba'))[0]['state'], 'completed');

        final forPlayer =
            (await send('GET', '/api/events', token: tokenA))['body']['events']
                as List;
        expect(forPlayer, hasLength(1));
        expect(forPlayer[0]['kind'], 'chapter_completed');
        expect(forPlayer[0]['payload']['characterName'], 'Sagan');
        expect(forPlayer[0]['payload']['campaignName'], 'La Tumba');
        expect(forPlayer[0]['payload']['chapterName'], 'La Cripta');
        expect(forPlayer[0]['payload']['grantsLevel'], isTrue);

        // Al DM que lo cerró no le llega nada: ya vio la respuesta.
        final forDm =
            (await send('GET', '/api/events', token: tokenB))['body']['events']
                as List;
        expect(forDm, isEmpty);
      });

      test('un capítulo sin nivel avisa sin la marca de nivel', () async {
        final tokenA = await login('ch-close-nolevel-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-nolevel-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(tokenB, 'tumba', 'cripta');

        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );

        final forPlayer =
            (await send('GET', '/api/events', token: tokenA))['body']['events']
                as List;
        final chapterEvent = forPlayer.firstWhere(
          (e) => e['kind'] == 'chapter_completed',
        );
        expect(chapterEvent['payload']['grantsLevel'], isFalse);
      });

      test('el botín del capítulo viaja en el aviso', () async {
        final tokenA = await login('ch-close-loot-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-loot-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(
          tokenB,
          'tumba',
          'cripta',
          grantsGold: 250,
          grantsItems: ['Espada larga +1', 'Poción de curación'],
        );

        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );

        final chapterEvent =
            ((await send('GET', '/api/events', token: tokenA))['body']['events']
                    as List)
                .firstWhere((e) => e['kind'] == 'chapter_completed');
        expect(chapterEvent['payload']['grantsGold'], 250);
        expect(chapterEvent['payload']['grantsItems'], [
          'Espada larga +1',
          'Poción de curación',
        ]);
      });

      // LA prueba de esta feature, y por eso es negativa: el DM anuncia el
      // botín y el aviso llega, pero **la ficha del jugador no se mueve**. El
      // oro y los ítems los anota él. Si algún día alguien hace que el cierre
      // escriba la ficha ajena, se entera acá.
      test(
        'cerrar un capítulo con botín no toca la ficha del jugador',
        () async {
          final tokenA = await login('ch-close-untouched-player');
          final code = await shareCharacter(tokenA, 'sagan');

          Future<Object?> sagan() async =>
              ((await send(
                        'GET',
                        '/api/characters',
                        token: tokenA,
                      ))['body']['characters']
                      as List)
                  .firstWhere((c) => c['character']['id'] == 'sagan');

          final before = await sagan();

          final tokenB = await login('ch-close-untouched-dm');
          await createCampaign(tokenB, 'tumba');
          await send(
            'POST',
            '/api/campaigns/tumba/members',
            token: tokenB,
            body: {'code': code},
          );
          await createChapter(
            tokenB,
            'tumba',
            'cripta',
            grantsLevel: true,
            grantsGold: 250,
            grantsItems: ['Espada larga +1'],
          );

          await send(
            'POST',
            '/api/campaigns/tumba/chapters/cripta/close',
            token: tokenB,
          );

          expect(await sagan(), before);
        },
      );

      test('un botín escrito mal se guarda limpio en vez de romper', () async {
        final token = await login('ch-loot-dirty');
        await createCampaign(token, 'tumba');
        final created = await createChapter(
          token,
          'tumba',
          'cripta',
          grantsGold: -50,
          grantsItems: ['  Espada larga +1  ', '', 7],
        );

        expect(created['status'], 200);
        expect(created['body']['chapter']['grantsGold'], 0);
        expect(created['body']['chapter']['grantsItems'], ['Espada larga +1']);
      });

      // Cerrar dos veces no es un error, pero tampoco vuelve a avisar.
      test('cerrar un capítulo ya cerrado no repite el aviso', () async {
        final tokenA = await login('ch-close-twice-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-twice-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(tokenB, 'tumba', 'cripta');

        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );
        final afterFirst =
            ((await send('GET', '/api/events', token: tokenA))['body']['events']
                    as List)
                .where((e) => e['kind'] == 'chapter_completed')
                .length;

        final second = await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );
        expect(second['status'], 200);

        final afterSecond =
            ((await send('GET', '/api/events', token: tokenA))['body']['events']
                    as List)
                .where((e) => e['kind'] == 'chapter_completed')
                .length;
        expect(afterSecond, afterFirst);
      });

      test('cerrar un capítulo inexistente responde 404', () async {
        final token = await login('ch-close-missing');
        await createCampaign(token, 'tumba');

        final response = await send(
          'POST',
          '/api/campaigns/tumba/chapters/fantasma/close',
          token: token,
        );

        expect(response['status'], 404);
      });

      test('borrar la campaña se lleva sus capítulos', () async {
        final token = await login('ch-cascade');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');

        await send('DELETE', '/api/campaigns/tumba', token: token);
        await createCampaign(token, 'tumba');

        expect(await listChapters(token, 'tumba'), isEmpty);
      });
    });

    group('cuaderno', () {
      Map<String, dynamic> noteJson(
        String id, {
        String chapterId = 'cripta',
        String title = 'Los tres sellos',
        String body = 'El tercero está detrás del tapiz.',
      }) => {
        'schemaVersion': 1,
        'id': id,
        'chapterId': chapterId,
        'title': title,
        'body': body,
      };

      Future<Map<String, dynamic>> createNote(
        String token,
        String campaignId,
        String id, {
        String chapterId = 'cripta',
        String title = 'Los tres sellos',
      }) => send(
        'POST',
        '/api/campaigns/$campaignId/notes',
        token: token,
        body: {'note': noteJson(id, chapterId: chapterId, title: title)},
      );

      Future<Map<String, dynamic>> notebook(
        String token,
        String campaignId,
      ) async {
        final response = await send(
          'GET',
          '/api/campaigns/$campaignId/notebook',
          token: token,
        );
        return response['body'] as Map<String, dynamic>;
      }

      /// Una campaña con un capítulo donde colgar notas.
      Future<String> tableWithChapter(String user) async {
        final token = await login(user);
        await createCampaign(token, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/chapters',
          token: token,
          body: {
            'chapter': {
              'schemaVersion': 1,
              'id': 'cripta',
              'name': 'La Cripta',
              'summary': '',
              'state': 'planned',
              'grantsLevel': false,
            },
          },
        );
        return token;
      }

      test('sin sesión ninguna operación responde 401', () async {
        for (final request in [
          Request(
            'GET',
            Uri.parse('http://localhost/api/campaigns/c1/notebook'),
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/api/campaigns/c1/notes'),
            body: jsonEncode({'note': noteJson('n1')}),
          ),
          Request(
            'PUT',
            Uri.parse('http://localhost/api/campaigns/c1/notes/n1'),
            body: jsonEncode({'note': noteJson('n1')}),
          ),
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/campaigns/c1/notes/n1'),
          ),
        ]) {
          expect(
            (await handler(request)).statusCode,
            401,
            reason: '${request.url}',
          );
        }
      });

      test('crear, listar, editar y borrar una nota', () async {
        final token = await tableWithChapter('nota-crud');

        final created = await createNote(token, 'tumba', 'sellos');
        expect(created['status'], 200);
        expect(created['body']['note']['title'], 'Los tres sellos');

        expect((await notebook(token, 'tumba'))['notes'], hasLength(1));

        final edited = await send(
          'PUT',
          '/api/campaigns/tumba/notes/sellos',
          token: token,
          body: {
            'note': noteJson('sellos', title: 'Los tres sellos (corregido)'),
          },
        );
        expect(edited['status'], 200);
        expect(
          ((await notebook(token, 'tumba'))['notes'] as List).single['title'],
          'Los tres sellos (corregido)',
        );

        await send('DELETE', '/api/campaigns/tumba/notes/sellos', token: token);
        expect((await notebook(token, 'tumba'))['notes'], isEmpty);
      });

      test('una nota necesita un capítulo que exista', () async {
        final token = await tableWithChapter('nota-sin-cap');
        final response = await createNote(
          token,
          'tumba',
          'suelta',
          chapterId: 'no-existe',
        );
        expect(response['status'], 400);
      });

      test('una nota sin título se rechaza', () async {
        final token = await tableWithChapter('nota-sin-titulo');
        final response = await send(
          'POST',
          '/api/campaigns/tumba/notes',
          token: token,
          body: {'note': noteJson('vacia', title: '   ')},
        );
        expect(response['status'], 400);
      });

      // Lo ajeno y lo inexistente responden igual, como en todo el resto del
      // espacio de campañas.
      test('el cuaderno de una campaña ajena no se ve ni se toca', () async {
        final owner = await tableWithChapter('nota-duena');
        await createNote(owner, 'tumba', 'sellos');
        final other = await login('nota-ajena');

        expect((await notebook(other, 'tumba'))['status'], isNull);
        for (final call in [
          send('GET', '/api/campaigns/tumba/notebook', token: other),
          send(
            'POST',
            '/api/campaigns/tumba/notes',
            token: other,
            body: {'note': noteJson('intrusa')},
          ),
          send(
            'PUT',
            '/api/campaigns/tumba/notes/sellos',
            token: other,
            body: {'note': noteJson('sellos', title: 'Pisada')},
          ),
          send('DELETE', '/api/campaigns/tumba/notes/sellos', token: other),
        ]) {
          expect((await call)['status'], 404);
        }

        // Y la nota de la dueña quedó intacta.
        final mine = (await notebook(owner, 'tumba'))['notes'] as List;
        expect(mine.single['title'], 'Los tres sellos');
      });

      test('borrar el capítulo se lleva sus notas', () async {
        final token = await tableWithChapter('nota-cascada');
        await createNote(token, 'tumba', 'sellos');
        expect((await notebook(token, 'tumba'))['notes'], hasLength(1));

        await send(
          'DELETE',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
        );

        expect((await notebook(token, 'tumba'))['notes'], isEmpty);
      });

      test('borrar la campaña se lleva el cuaderno', () async {
        final token = await tableWithChapter('nota-campana');
        await createNote(token, 'tumba', 'sellos');

        await send('DELETE', '/api/campaigns/tumba', token: token);
        await createCampaign(token, 'tumba');

        expect((await notebook(token, 'tumba'))['notes'], isEmpty);
      });

      // El cuaderno es el primer lector de `encounter_logs`: hasta ahora se
      // grababan y no los leía nadie.
      test('el combate cerrado aparece en el cuaderno', () async {
        final token = await tableWithChapter('nota-combate');

        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': {
              'schemaVersion': 1,
              'id': 'e1',
              'round': 4,
              'turnIndex': 0,
              'combatants': [
                {
                  'id': 'm1',
                  'kind': 'monster',
                  'name': 'Esqueleto 1',
                  'initiative': 12,
                  'creatureId': 'skeleton',
                  'currentHp': 0,
                  'maxHp': 13,
                },
                {
                  'id': 'm2',
                  'kind': 'monster',
                  'name': 'Esqueleto 2',
                  'initiative': 11,
                  'creatureId': 'skeleton',
                  'currentHp': 5,
                  'maxHp': 13,
                },
              ],
            },
          },
        );
        await send('DELETE', '/api/campaigns/tumba/encounter', token: token);

        final logs = (await notebook(token, 'tumba'))['encounterLogs'] as List;
        expect(logs, hasLength(1));
        expect(logs.single['rounds'], 4);
        // Las copias se agrupan y el número de la mesa se saca del nombre.
        final monsters = logs.single['monsters'] as List;
        expect(monsters.single['name'], 'Esqueleto');
        expect(monsters.single['count'], 2);
        expect(monsters.single['defeated'], 1);
      });

      test('un combate descartado no deja entrada', () async {
        final token = await tableWithChapter('nota-descarte');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': {
              'schemaVersion': 1,
              'id': 'e1',
              'round': 1,
              'turnIndex': 0,
              'combatants': <dynamic>[],
            },
          },
        );
        await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=true',
          token: token,
        );

        expect((await notebook(token, 'tumba'))['encounterLogs'], isEmpty);
      });
    });

    group('combate', () {
      Map<String, dynamic> playerCombatant(
        String id, {
        required String memberId,
        int initiative = 10,
      }) => {
        'id': id,
        'kind': 'player',
        'name': 'PJ',
        'initiative': initiative,
        'memberId': memberId,
      };

      Map<String, dynamic> monsterCombatant(
        String id, {
        int initiative = 5,
        int currentHp = 7,
        int maxHp = 7,
        String name = 'Goblin',
      }) => {
        'id': id,
        'kind': 'monster',
        'name': name,
        'initiative': initiative,
        'creatureId': 'goblin',
        'currentHp': currentHp,
        'maxHp': maxHp,
      };

      Map<String, dynamic> encounterJson({
        String id = 'e1',
        int round = 1,
        int turnIndex = 0,
        required List<Map<String, dynamic>> combatants,
      }) => {
        'schemaVersion': 1,
        'id': id,
        'round': round,
        'turnIndex': turnIndex,
        'combatants': combatants,
      };

      test('sin sesión ninguna operación responde 401', () async {
        for (final request in [
          Request(
            'GET',
            Uri.parse('http://localhost/api/campaigns/c1/encounter'),
          ),
          Request(
            'PUT',
            Uri.parse('http://localhost/api/campaigns/c1/encounter'),
            body: jsonEncode({'encounter': encounterJson(combatants: [])}),
          ),
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/campaigns/c1/encounter'),
          ),
          Request('GET', Uri.parse('http://localhost/api/characters/x/turn')),
        ]) {
          expect(
            (await handler(request)).statusCode,
            401,
            reason: '${request.url}',
          );
        }
      });

      test('guardar y releer un encuentro', () async {
        final token = await login('enc-roundtrip');
        await createCampaign(token, 'tumba');

        final saved = await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': encounterJson(combatants: [monsterCombatant('m1')]),
          },
        );
        expect(saved['status'], 200);

        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(read['status'], 200);
        expect(read['body']['encounter']['combatants'], hasLength(1));
      });

      test('sin combate abierto, la lectura responde 404', () async {
        final token = await login('enc-none');
        await createCampaign(token, 'tumba');

        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(read['status'], 404);
        expect(read['body']['error'], 'No hay ningún combate en curso.');
      });

      test('un DM ajeno recibe 404 al leer y al guardar', () async {
        final tokenA = await login('enc-owner');
        await createCampaign(tokenA, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenA,
          body: {'encounter': encounterJson(combatants: [])},
        );

        final tokenB = await login('enc-intruder');
        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: tokenB,
        );
        expect(read['status'], 404);

        final write = await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenB,
          body: {'encounter': encounterJson(combatants: [])},
        );
        expect(write['status'], 404);
      });

      test(
        'cerrar el combate borra el encuentro y deja el log grabado',
        () async {
          final token = await login('enc-close');
          await createCampaign(token, 'tumba');
          await send(
            'PUT',
            '/api/campaigns/tumba/encounter',
            token: token,
            body: {
              'encounter': encounterJson(
                round: 3,
                combatants: [
                  playerCombatant(
                    'p1',
                    memberId: '00000000-0000-4000-8000-000000000000',
                  ),
                  monsterCombatant('m1', currentHp: 0),
                ],
              ),
            },
          );

          final closed = await send(
            'DELETE',
            '/api/campaigns/tumba/encounter',
            token: token,
          );
          expect(closed['status'], 200);

          final afterClose = await send(
            'GET',
            '/api/campaigns/tumba/encounter',
            token: token,
          );
          expect(afterClose['status'], 404);

          expect(encounters.logs, hasLength(1));
          expect(encounters.logs.single.document['rounds'], 3);
          expect(encounters.logs.single.document['monsters'], hasLength(1));
          expect(encounters.logs.single.document['monsters'][0]['defeated'], 1);
        },
      );

      // Un combate abierto por error no tiene por qué quedar en el registro
      // de la campaña como si se hubiera jugado.
      test('descartar el combate no deja log', () async {
        final token = await login('enc-discard');
        await createCampaign(token, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': encounterJson(combatants: [monsterCombatant('m1')]),
          },
        );

        final discarded = await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=true',
          token: token,
        );
        expect(discarded['status'], 200);

        final afterDiscard = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(afterDiscard['status'], 404);
        expect(encounters.logs, isEmpty);
      });

      // Perder lo jugado tiene que ser una decisión explícita: un parámetro
      // mal escrito archiva, no descarta.
      test('un "discard" que no es exactamente true archiva igual', () async {
        final token = await login('enc-discard-typo');
        await createCampaign(token, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': encounterJson(combatants: [monsterCombatant('m1')]),
          },
        );

        await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=si',
          token: token,
        );

        expect(encounters.logs, hasLength(1));
      });

      test('un DM ajeno no puede descartar el combate de otro', () async {
        final tokenA = await login('enc-discard-owner');
        await createCampaign(tokenA, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenA,
          body: {'encounter': encounterJson(combatants: [])},
        );

        final tokenB = await login('enc-discard-intruder');
        final response = await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=true',
          token: tokenB,
        );
        expect(response['status'], 404);

        // Y el combate del dueño sigue en pie.
        final stillThere = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: tokenA,
        );
        expect(stillThere['status'], 200);
      });

      test('cerrar sin combate abierto no hace nada', () async {
        final token = await login('enc-close-empty');
        await createCampaign(token, 'tumba');

        final closed = await send(
          'DELETE',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(closed['status'], 200);
        expect(encounters.logs, isEmpty);
      });

      test('borrar la campaña deja el combate inaccesible', () async {
        final token = await login('enc-cascade');
        await createCampaign(token, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {'encounter': encounterJson(combatants: [])},
        );

        await send('DELETE', '/api/campaigns/tumba', token: token);

        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(read['status'], 404);
      });

      test('el jugador vinculado obtiene su turno correcto', () async {
        final tokenA = await login('turn-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('turn-b');
        await createCampaign(tokenB, 'tumba');
        final redeemed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        final memberId = redeemed['body']['member']['memberId'] as String;

        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenB,
          body: {
            'encounter': encounterJson(
              combatants: [
                playerCombatant('p1', memberId: memberId, initiative: 20),
                monsterCombatant('m1', initiative: 10),
              ],
            ),
          },
        );

        final turn = await send(
          'GET',
          '/api/characters/sagan/turn',
          token: tokenA,
        );
        expect(turn['body']['turn'], 'active');
      });

      test('un jugador sin vínculo obtiene "none", no un error', () async {
        final token = await login('turn-none');
        await send(
          'POST',
          '/api/characters',
          token: token,
          body: {'character': characterJson('sagan')},
        );

        final turn = await send(
          'GET',
          '/api/characters/sagan/turn',
          token: token,
        );
        expect(turn['status'], 200);
        expect(turn['body']['turn'], 'none');
      });

      test(
        'un jugador no puede preguntar por el turno de un personaje ajeno',
        () async {
          final tokenA = await login('turn-owner');
          await send(
            'POST',
            '/api/characters',
            token: tokenA,
            body: {'character': characterJson('sagan')},
          );

          final tokenB = await login('turn-intruder');
          final turn = await send(
            'GET',
            '/api/characters/sagan/turn',
            token: tokenB,
          );
          expect(turn['status'], 404);
        },
      );
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
