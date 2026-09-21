import 'dart:async';
import 'dart:convert';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('usa un timeout finito de 15 segundos por defecto', () {
    expect(ApiClient.defaultRequestTimeout, const Duration(seconds: 15));
  });

  test(
    'una respuesta que nunca llega termina como error de conectividad',
    () async {
      final response = Completer<http.StreamedResponse>();
      final client = _ControlledClient((_) => response.future);
      final api = ApiClient(
        client: client,
        requestTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        api.currentAccount(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having(
                (e) => e.message,
                'message',
                'La conexión tardó demasiado en responder.',
              ),
        ),
      );
      expect(client.requests, 1);
    },
  );

  test(
    'un cuerpo que se estanca también queda limitado por el timeout',
    () async {
      final body = StreamController<List<int>>();
      final client = _ControlledClient(
        (_) async => http.StreamedResponse(body.stream, 200),
      );
      final api = ApiClient(
        client: client,
        requestTimeout: const Duration(milliseconds: 20),
      );

      try {
        await expectLater(
          api.currentAccount(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              isNull,
            ),
          ),
        );
      } finally {
        await body.close();
      }
    },
  );

  test('una respuesta completa dentro del límite conserva el modelo', () async {
    final client = _ControlledClient(
      (_) async => _jsonResponse({
        'userId': 'ada',
        'name': 'Ada Lovelace',
        'email': 'ada@example.org',
        'pictureUrl': null,
      }),
    );
    final api = ApiClient(
      client: client,
      requestTimeout: const Duration(seconds: 1),
    );

    final account = await api.currentAccount();

    expect(account?.userId, 'ada');
    expect(account?.name, 'Ada Lovelace');
  });

  test('un error HTTP conserva su código y mensaje', () async {
    final api = ApiClient(
      client: _ControlledClient(
        (_) async => _jsonResponse({
          'error': 'Servicio no disponible.',
        }, statusCode: 503),
      ),
      requestTimeout: const Duration(seconds: 1),
    );

    await expectLater(
      api.currentAccount(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.message, 'message', 'Servicio no disponible.'),
      ),
    );
  });

  test(
    'cancelar invalida el resultado viejo y permite un pedido nuevo',
    () async {
      final oldResponse = Completer<http.StreamedResponse>();
      late _ControlledClient client;
      client = _ControlledClient((request) async {
        if (client.requests == 1) return oldResponse.future;
        return _jsonResponse({'userId': 'new'});
      });
      final api = ApiClient(
        client: client,
        requestTimeout: const Duration(seconds: 1),
      );

      final old = api.currentAccount();
      api.cancelPendingRequests();
      final current = await api.currentAccount();

      expect(current?.userId, 'new');
      oldResponse.complete(_jsonResponse({'userId': 'old'}));
      await expectLater(
        old,
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
      expect(client.requests, 2);
      expect(client.closeCalls, 0);
    },
  );

  test('una mutación expirada no se reintenta automáticamente', () async {
    final response = Completer<http.StreamedResponse>();
    final client = _ControlledClient((_) => response.future);
    final api = ApiClient(
      client: client,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      api.saveSettingsDocument({'themeMode': 'dark'}),
      throwsA(isA<ApiException>()),
    );

    expect(client.requests, 1);
  });
}

class _ControlledClient extends http.BaseClient {
  _ControlledClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;
  int requests = 0;
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    return _handler(request);
  }

  @override
  void close() => closeCalls++;
}

http.StreamedResponse _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) => http.StreamedResponse(
  Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
  statusCode,
  headers: {'content-type': 'application/json'},
);
