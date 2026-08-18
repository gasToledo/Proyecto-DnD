import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/ui/pending_events_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  // Regresión directa del bug reportado: los avisos se chequeaban una sola
  // vez en el arranque de la app, así que si la pestaña ya estaba abierta
  // (entrar a Modo DM, abrir una ficha) nunca se volvía a preguntar.
  testWidgets('muestra un aviso pendiente apenas se monta', (tester) async {
    final server = FakeApiServer();
    server.events.add({
      'id': '00000000-0000-4000-9000-000000000000',
      'kind': 'character_linked',
      'payload': {'characterName': 'Sagan', 'campaignName': 'La Tumba'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PendingEventsGate(
          api: ApiClient(client: server.client),
          child: const Scaffold(body: Text('contenido')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sagan'), findsOneWidget);
    expect(find.textContaining('La Tumba'), findsOneWidget);
  });

  // Sin esto, el mismo aviso volvería a aparecer cada vez que se entra a una
  // pantalla que lo chequea.
  testWidgets('marca visto el aviso después de mostrarlo', (tester) async {
    final server = FakeApiServer();
    server.events.add({
      'id': '00000000-0000-4000-9000-000000000000',
      'kind': 'character_linked',
      'payload': {'characterName': 'Sagan', 'campaignName': 'La Tumba'},
    });
    final api = ApiClient(client: server.client);

    await tester.pumpWidget(
      MaterialApp(
        home: PendingEventsGate(
          api: api,
          child: const Scaffold(body: Text('contenido')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await api.listUnseenEvents(), isEmpty);
  });

  testWidgets('sin avisos pendientes no muestra nada', (tester) async {
    final server = FakeApiServer();

    await tester.pumpWidget(
      MaterialApp(
        home: PendingEventsGate(
          api: ApiClient(client: server.client),
          child: const Scaffold(body: Text('contenido')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  // Un `kind` que este cliente todavía no conoce no puede romper la pantalla:
  // el servidor puede ser más nuevo que la pestaña abierta.
  testWidgets('un aviso de tipo desconocido no rompe nada', (tester) async {
    final server = FakeApiServer();
    server.events.add({
      'id': '00000000-0000-4000-9000-000000000000',
      'kind': 'algo_que_todavia_no_existe',
      'payload': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PendingEventsGate(
          api: ApiClient(client: server.client),
          child: const Scaffold(body: Text('contenido')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('checkPendingEvents se puede llamar directo, sin el widget', (
    tester,
  ) async {
    final server = FakeApiServer();
    server.events.add({
      'id': '00000000-0000-4000-9000-000000000000',
      'kind': 'character_unlinked_by_dm',
      'payload': {'characterName': 'Sagan', 'campaignName': 'La Tumba'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: (context) => const Text('x'))),
      ),
    );
    final context = tester.element(find.text('x'));

    await checkPendingEvents(context, ApiClient(client: server.client));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sagan'), findsOneWidget);
  });
}
