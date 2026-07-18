import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_app/demo/demo_characters.dart';

void main() {
  test('el personaje de demostración es coherente', () {
    final sagan = demoSagan();
    expect(sagan.classId, 'fighter');
    // Round-trip de serialización (base del formato de exportación).
    final restored = Character.fromJson(sagan.toJson());
    expect(restored.name, sagan.name);
    expect(restored.weaponMasteryChoices, sagan.weaponMasteryChoices);
  });
}
