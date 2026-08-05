import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/ai/portrait_prompt.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:flutter_test/flutter_test.dart';

// La generación en sí (proveedores, servicios de Azure/Pollinations) vive
// ahora en dnd_server (ver `packages/dnd_server/test/ai/`, capacidad
// `ai-portrait-generation`): este cliente solo arma el prompt y llama al
// endpoint del servidor, así que lo único que queda pendiente de probar acá
// es esa construcción de texto, que es pura.
void main() {
  group('buildPortraitPrompt', () {
    late ContentRepository repo;
    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory(
        '../dnd_engine/lib/assets/srd_2024',
      );
    });

    test('auto-completa raza, clase, armadura, arma y estilo', () {
      final prompt = buildPortraitPrompt(
        character: demoSagan(),
        repo: repo,
        style: 'Óleo clásico',
        extraText: 'pelo rojo largo',
      );
      expect(prompt, contains('Humano Guerrero'));
      expect(prompt, contains('Armadura de cuero'));
      expect(prompt, contains('Espada larga'));
      expect(prompt, contains('pelo rojo largo'));
      expect(prompt, contains('Estilo: Óleo clásico'));
    });

    test(
      'con includeWeapon: false omite el arma pero conserva la armadura',
      () {
        final prompt = buildPortraitPrompt(
          character: demoSagan(),
          repo: repo,
          style: 'Óleo clásico',
          extraText: '',
          includeWeapon: false,
        );
        expect(prompt, contains('Armadura de cuero'));
        expect(prompt, isNot(contains('Espada larga')));
      },
    );
  });
}
