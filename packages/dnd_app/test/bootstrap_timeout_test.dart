import 'dart:async';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/main.dart';
import 'package:dnd_app/ui/dashboard_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes/fake_api_server.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'dnd_app',
      packageName: 'dnd_app.test',
      version: 'test',
      buildNumber: '1',
      buildSignature: 'test',
    );
  });

  testWidgets('el timeout de sesión reemplaza el spinner por un retry', (
    tester,
  ) async {
    final server = FakeApiServer();
    final transport = _BootstrapClient(server, blockedPath: '/api/me');
    final api = ApiClient(
      client: transport,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await tester.pumpWidget(
      DndApp(api: api, contentLoader: () async => ContentRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('No se pudo iniciar la aplicación.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Cargando datos…'), findsNothing);

    transport.release();
  });

  testWidgets('el retry posterior al timeout llega al dashboard', (
    tester,
  ) async {
    final server = FakeApiServer();
    final transport = _BootstrapClient(server, blockedPath: '/api/me');
    final api = ApiClient(
      client: transport,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await tester.pumpWidget(
      DndApp(api: api, contentLoader: () async => ContentRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Reintentar'), findsOneWidget);

    transport.blockedPath = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.text('Cargando datos…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('No se pudo iniciar la aplicación.'), findsNothing);

    transport.release();
  });

  testWidgets('el timeout de personajes usa el estado offline recuperable', (
    tester,
  ) async {
    final server = FakeApiServer();
    final transport = _BootstrapClient(server, blockedPath: '/api/characters');
    final api = ApiClient(
      client: transport,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await tester.pumpWidget(
      DndApp(api: api, contentLoader: () async => ContentRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.textContaining('Tus personajes están a salvo'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Cargando datos…'), findsNothing);

    transport.release();
  });

  // Con la sesión confirmada, homebrew, personajes y ajustes se piden juntos:
  // en serie sumaban ~240 ms de red en producción. Si uno vuelve a esperar al
  // otro, los personajes no llegan a pedirse mientras el homebrew no contesta.
  testWidgets('con sesión, las cargas del arranque salen juntas', (
    tester,
  ) async {
    final server = FakeApiServer();
    final transport = _BootstrapClient(server, blockedPath: '/api/homebrew');
    final api = ApiClient(
      client: transport,
      requestTimeout: const Duration(seconds: 5),
    );

    await tester.pumpWidget(
      DndApp(api: api, contentLoader: () async => ContentRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(transport.requested, contains('/api/homebrew'));
    expect(transport.requested, contains('/api/characters'));
    expect(transport.requested, contains('/api/settings'));
    expect(find.byType(DashboardScreen), findsNothing);

    transport.release();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('desmontar durante el arranque invalida la respuesta tardía', (
    tester,
  ) async {
    final server = FakeApiServer();
    final transport = _BootstrapClient(server, blockedPath: '/api/me');
    final api = ApiClient(
      client: transport,
      requestTimeout: const Duration(seconds: 1),
    );

    await tester.pumpWidget(DndApp(api: api));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    transport.release();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(DashboardScreen), findsNothing);
  });
}

class _BootstrapClient extends http.BaseClient {
  _BootstrapClient(this.server, {this.blockedPath});

  final FakeApiServer server;
  String? blockedPath;
  final _release = Completer<void>();
  final requested = <String>[];

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url.path);
    if (request.url.path == blockedPath) await _release.future;
    final response = await server.client.send(request);
    return response;
  }
}
