import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/ai/portrait_prompt.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/portrait_image.dart';
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
  // lavado con `medium`: hay que recibirlo cerca del tamaño final, no filtrar
  // más fuerte.
  //
  // Reducirlo en el cliente **no es una alternativa**: la implementación web de
  // `NetworkImage` no admite decodificar a un tamaño dado, así que un
  // `ResizeImage` alrededor no hace nada en el navegador (que es la plataforma
  // que se publica) y el retrato llega entero igual. Por eso lo que se prueba
  // acá es que el medallón *pida* la miniatura, no que la decodifique.
  group('Medallion', () {
    ImageProvider sourceOf(WidgetTester tester) {
      final decoration =
          tester.widget<Container>(find.byType(Container)).decoration
              as BoxDecoration;
      return decoration.image!.image;
    }

    Future<void> pumpMedallion(WidgetTester tester, double size) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Medallion(
              portraitKey: 'sagan/x.png',
              fallback: 'S',
              size: size,
            ),
          ),
        );

    testWidgets('pide la miniatura del tamaño en que se dibuja', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await pumpMedallion(tester, 60);

      // 60 lógicos x 2 de densidad son 120 px físicos, y el peldaño que los
      // cubre es 128. Sin el `?w=`, el servidor manda el original de 1024.
      expect(
        (sourceOf(tester) as NetworkImage).url,
        '/api/portraits/sagan/x.png?w=128',
        reason: 'el retrato se está pidiendo a resolución completa',
      );
    });

    testWidgets('sobre el peldaño más grande pide el original', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // 400 lógicos x 3 pasan de 512, el ancho máximo de la escalera: ahí una
      // miniatura habría que estirarla, así que corresponde el original.
      await pumpMedallion(tester, 400);

      expect(
        (sourceOf(tester) as NetworkImage).url,
        '/api/portraits/sagan/x.png',
      );
    });
  });

  group('PortraitImage.thumbnailWidthFor', () {
    test('redondea al peldaño de arriba, nunca al de abajo', () {
      // Redondear para abajo es agrandar al dibujar, que es justo lo que no
      // puede pasar: un retrato estirado se ve peor que uno reducido de más.
      expect(PortraitImage.thumbnailWidthFor(76, 1), 96);
      expect(PortraitImage.thumbnailWidthFor(96, 1), 96);
      expect(PortraitImage.thumbnailWidthFor(96.5, 1), 128);
      expect(PortraitImage.thumbnailWidthFor(42, 2), 96);
      expect(PortraitImage.thumbnailWidthFor(512, 1), 512);
      expect(PortraitImage.thumbnailWidthFor(513, 1), isNull);
    });
  });
}
