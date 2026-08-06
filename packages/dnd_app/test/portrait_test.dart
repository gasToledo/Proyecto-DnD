import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/ai/portrait_prompt.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
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

  // Los retratos llegan a 768 o 1024 px de lado y el medallón del roster mide
  // menos de 100. Reducir eso al dibujar sale dentado con `FilterQuality.low` y
  // lavado con `medium`: hay que decodificar cerca del tamaño final, no filtrar
  // más fuerte. Si alguien saca el `ResizeImage`, esto lo tiene que decir.
  group('Medallion', () {
    testWidgets('decodifica el retrato al tamaño en que se dibuja', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Medallion(
            image: const NetworkImage('/api/portraits/x.png'),
            fallback: 'S',
            size: 60,
          ),
        ),
      );

      final decoration =
          tester.widget<Container>(find.byType(Container)).decoration
              as BoxDecoration;
      final source = decoration.image!.image;

      expect(
        source,
        isA<ResizeImage>(),
        reason: 'el retrato se está dibujando a resolución completa',
      );
      // 60 lógicos x 2 de densidad, con el margen que `BoxFit.cover` necesita
      // para no agrandar una imagen apaisada.
      expect((source as ResizeImage).width, 240);
      expect(
        source.allowUpscaling,
        isFalse,
        reason: 'un retrato chico no debe estirarse al decodificar',
      );
    });
  });
}
