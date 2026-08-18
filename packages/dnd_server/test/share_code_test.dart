import 'package:dnd_server/src/sharing/share_code.dart';
import 'package:test/test.dart';

void main() {
  group('generateShareCode', () {
    test('tiene la forma XXXX-XXXX', () {
      for (var i = 0; i < 50; i++) {
        expect(
          generateShareCode(),
          matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$')),
        );
      }
    });

    // Un carácter ambiguo es un código que la persona tipea mal y cree que la
    // app está rota.
    test('nunca usa caracteres que se confunden al leerlos', () {
      for (var i = 0; i < 200; i++) {
        expect(generateShareCode(), isNot(matches(RegExp('[ILOU01]'))));
      }
    });

    test('no repite el mismo código', () {
      final codes = {for (var i = 0; i < 200; i++) generateShareCode()};

      expect(codes, hasLength(200));
    });
  });

  group('normalizeShareCode', () {
    test('saca el guion y sube a mayúsculas', () {
      expect(normalizeShareCode('k7m2-qx9a'), 'K7M2QX9A');
    });

    test('tolera los espacios de más que deja copiar de un chat', () {
      expect(normalizeShareCode('  K7M2 - QX9A \n'), 'K7M2QX9A');
    });

    test('es idempotente', () {
      final once = normalizeShareCode('k7m2-qx9a');

      expect(normalizeShareCode(once), once);
    });

    test('descarta lo que no pertenece al alfabeto', () {
      expect(normalizeShareCode('K7M2/QX9A!'), 'K7M2QX9A');
    });
  });

  group('hashShareCode', () {
    // El DM pega el código como le llegó: todas esas formas son el mismo
    // código y tienen que resolver a la misma fila.
    test('las formas equivalentes dan el mismo hash', () {
      final canonical = hashShareCode('K7M2QX9A');

      expect(hashShareCode('k7m2-qx9a'), canonical);
      expect(hashShareCode('K7M2-QX9A'), canonical);
      expect(hashShareCode(' k7m2 qx9a '), canonical);
    });

    test('códigos distintos dan hashes distintos', () {
      expect(hashShareCode('K7M2QX9A'), isNot(hashShareCode('K7M2QX9B')));
    });

    // Si la base se filtra, no debe entregar accesos válidos.
    test('el hash no contiene el código', () {
      expect(hashShareCode('K7M2QX9A'), isNot(contains('K7M2')));
    });
  });
}
