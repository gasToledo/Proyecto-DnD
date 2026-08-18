import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/api/api_exception.dart';
import 'package:dnd_app/data/campaigns_controller.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';

void main() {
  late FakeApiServer server;
  late CampaignsController controller;

  setUp(() {
    server = FakeApiServer();
    controller = CampaignsController(ApiClient(client: server.client));
  });

  test('crea una campaña y queda en la lista', () async {
    final created = await controller.create('La Tumba');

    expect(created.name, 'La Tumba');
    expect(controller.campaigns, hasLength(1));
    expect(server.campaigns[created.id]?.name, 'La Tumba');
  });

  // El id sale del nombre para que sea legible, pero el nombre lo escribe una
  // persona: no puede llegar cualquier cosa a la URL.
  test('el id derivado del nombre es apto para una ruta', () async {
    final created = await controller.create('¡La Tumba de la Aniquilación!');

    expect(created.id, matches(RegExp(r'^[a-z0-9-]+$')));
  });

  test('un nombre sin caracteres usables igual produce un id', () async {
    final created = await controller.create('🐉🗡️');

    expect(created.id, isNotEmpty);
    expect(created.id, matches(RegExp(r'^[a-z0-9-]+$')));
  });

  // El servidor reasigna el id ante colisión: la lista tiene que quedarse con
  // el que efectivamente se guardó, no con el que se pidió.
  test(
    'si el id ya estaba en uso se queda con el que asignó el servidor',
    () async {
      final first = await controller.create('La Tumba');
      final second = await controller.create('La Tumba');

      expect(second.id, isNot(first.id));
      expect(
        controller.campaigns.map((c) => c.id),
        containsAll([first.id, second.id]),
      );
    },
  );

  test('la lista queda ordenada por nombre', () async {
    await controller.create('Zafiro');
    await controller.create('Abadía');

    await controller.load();

    expect(controller.campaigns.first.name, 'Abadía');
  });

  test('renombrar actualiza la lista y el servidor', () async {
    final created = await controller.create('Vieja');

    await controller.update(created.copyWith(name: 'Nueva'));

    expect(controller.campaigns.single.name, 'Nueva');
    expect(server.campaigns[created.id]?.name, 'Nueva');
  });

  test('borrar la saca de la lista', () async {
    final created = await controller.create('La Tumba');

    await controller.delete(created.id);

    expect(controller.campaigns, isEmpty);
    expect(server.campaigns, isEmpty);
  });

  // Sin conexión no es lo mismo que una cuenta sin campañas: una ofrece
  // reintentar y la otra ofrece crear la primera.
  test('sin conexión se marca como tal en vez de propagar', () async {
    server.failWith = Exception('sin red');

    await controller.load();

    expect(controller.loadFailedOffline, isTrue);
    expect(controller.campaigns, isEmpty);
  });

  test('un error que no es de conexión se propaga', () async {
    server.authenticated = false;

    expect(
      () => controller.load(),
      throwsA(
        isA<ApiException>().having((e) => e.isAuthError, 'es 401', isTrue),
      ),
    );
  });

  test('avisa a quien la escucha en cada cambio', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.create('La Tumba');

    expect(notifications, greaterThan(0));
  });

  test('el estado por defecto de una campaña nueva es en curso', () async {
    final created = await controller.create('La Tumba');

    expect(created.state, CampaignState.active);
  });
}
