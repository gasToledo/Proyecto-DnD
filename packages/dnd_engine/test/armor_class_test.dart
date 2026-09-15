import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      'lib/assets/srd_2024',
    );
  });

  // La cuenta la comparten el compilador y la vista previa del formulario
  // homebrew: si se separan, la ficha y el formulario muestran CAs distintas.
  test('la Destreza suma hasta el tope de la armadura, y en contra entera', () {
    final media = repo.armorPiece('breastplate')!;
    final tope = media.maxDexBonus!;

    expect(media.armorClassFor(tope + 2), media.baseAc + tope);
    expect(media.armorClassFor(tope - 1), media.baseAc + tope - 1);
    expect(media.armorClassFor(-1), media.baseAc - 1);
  });

  test('la ligera suma la Destreza entera y la pesada nada', () {
    final ligera = repo.armorPiece('leather')!;
    final pesada = repo.armorPiece('plate')!;

    expect(ligera.armorClassFor(5), ligera.baseAc + 5);
    expect(pesada.armorClassFor(5), pesada.baseAc);
  });
}
