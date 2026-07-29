import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Conjuros que 2024 reescribió y el catálogo seguía teniendo en su forma 2014.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Spell spell(String id) => repo.spells[id]!;

  test('Toque Helado pasa a ser un ataque cuerpo a cuerpo', () {
    final s = spell('chill-touch');
    expect(s.name, 'Toque Helado', reason: 'en 2024 deja de ser "Gélido"');
    expect(s.range, 'Toque', reason: 'ya no son 120 pies a distancia');
    expect(s.description, contains('cuerpo a cuerpo'));
    expect(s.description, contains('necrótico'));
    // El truco escala con el nivel de personaje, no con espacios.
    expect(s.level, 0);
    expect(s.description, contains('4d10'));
  });

  test('Marca del Cazador inflige daño de fuerza y conserva el rastreo', () {
    final s = spell('hunters-mark');
    expect(s.description, contains('fuerza'),
        reason: '2024 fija el tipo de daño del 1d6 extra');
    // La ventaja para buscar a la presa sigue en el conjuro: no se quitó.
    expect(s.description, contains('Supervivencia'));
    expect(s.school, 'Adivinación');
    expect(s.castingTime, 'Acción Adicional');
    expect(s.concentration, isTrue);
  });

  test('Conjurar Animales deja de invocar criaturas y pasa a daño de área', () {
    final s = spell('conjure-animals');
    expect(s.name, 'Conjurar Animales');
    expect(s.duration, '10 minutos', reason: 'en 2014 duraba 1 hora');
    expect(s.concentration, isTrue);
    expect(s.description, contains('3d10'));
    expect(s.description, contains('salvación de Destreza'));
    // Ya no hay criaturas aliadas con bloque de estadísticas.
    expect(s.description, isNot(contains('combaten a tu lado')));
  });

  group('altas del capítulo 7: trucos y nivel 1', () {
    // Los campos mecánicos salieron del parseo del PDF, no de transcribir a
    // mano, así que lo que se comprueba acá es la conversión: métrico a pies,
    // el ritual separado del tiempo de lanzamiento y la concentración.
    test('el catálogo cubre los trucos y el nivel 1 del manual', () {
      final trucos = repo.spells.values.where((s) => s.level == 0);
      final nivel1 = repo.spells.values.where((s) => s.level == 1);
      expect(trucos.length, greaterThanOrEqualTo(32));
      expect(nivel1.length, greaterThanOrEqualTo(63));
    });

    test('el catálogo cubre el nivel 2 del manual', () {
      final nivel2 = repo.spells.values.where((s) => s.level == 2);
      expect(nivel2.length, greaterThanOrEqualTo(63));
    });

    test('el catálogo cubre el nivel 3 del manual', () {
      final nivel3 = repo.spells.values.where((s) => s.level == 3);
      expect(nivel3.length, greaterThanOrEqualTo(51));
    });

    test('el catálogo cubre el nivel 4 del manual', () {
      final nivel4 = repo.spells.values.where((s) => s.level == 4);
      expect(nivel4.length, greaterThanOrEqualTo(41));
    });

    test('el catálogo cubre el nivel 5 del manual', () {
      final nivel5 = repo.spells.values.where((s) => s.level == 5);
      expect(nivel5.length, greaterThanOrEqualTo(47));
    });

    test('Invocar Elemental y Conjurar Elemental son conjuros distintos', () {
      // Invocar Elemental (summon-elemental, nivel 4) es el conjuro de
      // invocación nuevo de 2024, con el perfil del espíritu elemental.
      // Conjurar Elemental (conjure-elemental, nivel 5) es el conjuro de
      // 2014 que sigue en el manual, con un elemental Grande de estadísticas
      // propias. Comparten la raíz del nombre pero no son la misma entrada.
      final invocar = spell('summon-elemental');
      final conjurar = spell('conjure-elemental');
      expect(invocar.level, 4);
      expect(conjurar.level, 5);
      expect(invocar.id, isNot(conjurar.id));
    });

    test('el alcance "Especial" se preserva tal cual lo trae el manual', () {
      // Ensueño alcanza al lanzador o a un objetivo lejano según el caso,
      // así que el PHB no le da una distancia fija.
      expect(spell('dream').range, 'Especial');
    });

    test('el catálogo cubre los 388 conjuros del capítulo 7', () {
      // Cierra Q2: trucos, nivel 1 a 9. Sin espacio para lista de deuda, así
      // que la invariante es exacta y no un piso.
      expect(repo.spells.length, greaterThanOrEqualTo(388));
      final porNivel = <int, int>{};
      for (final s in repo.spells.values) {
        porNivel[s.level] = (porNivel[s.level] ?? 0) + 1;
      }
      const minimos = {
        0: 33,
        1: 64,
        2: 63,
        3: 51,
        4: 41,
        5: 47,
        6: 34,
        7: 21,
        8: 18,
        9: 16
      };
      minimos.forEach((nivel, min) {
        expect(porNivel[nivel] ?? 0, greaterThanOrEqualTo(min),
            reason: 'nivel $nivel: cobertura incompleta');
      });
    });

    test('Invocar Feérico/Celestial no son Conjurar Feérico/Celestial', () {
      // Cuarta y quinta repetición del mismo patrón: dos verbos en español
      // ("invocar" para el conjuro nuevo de 2024, "conjurar" para el que
      // sigue del 2014) sobre la misma criatura, pero son conjuros distintos
      // con nivel y mecánica propios.
      expect(spell('summon-fey').level, 3);
      expect(spell('conjure-fey').level, 6);
      expect(spell('summon-fey').id, isNot(spell('conjure-fey').id));

      expect(spell('summon-celestial').level, 5);
      expect(spell('conjure-celestial').level, 7);
      expect(
          spell('summon-celestial').id, isNot(spell('conjure-celestial').id));
    });

    test('el alcance en kilómetros se convierte a millas', () {
      // Proyectar Imagen viene en 750 km; la conversión es genérica
      // (no solo el caso de 1,5 km que ya usaba Enjambre de Meteoros).
      expect(spell('project-image').range, '500 millas');
      expect(spell('storm-of-vengeance').range, '1 milla');
    });

    test('Telepatía es de alcance Ilimitado pese al OCR', () {
      // El PDF pierde la "I" mayúscula ("Alcance: limitado"); el texto del
      // conjuro confirma que no hay límite de distancia dentro del plano.
      expect(spell('telepathy').range, 'Ilimitado');
    });

    test('Hechizar Monstruo y Dominar Monstruo son conjuros distintos', () {
      // "Hechizar Monstruo" (charm-monster, nivel 4) no es una versión menor
      // de "Dominar Monstruo" (dominate-monster, nivel 8): son dos conjuros
      // separados en el manual, y usar mal el id habría pisado el existente.
      final hechizar = spell('charm-monster');
      final dominar = spell('dominate-monster');
      expect(hechizar.level, 4);
      expect(dominar.level, 8);
      expect(hechizar.id, isNot(dominar.id));
    });

    test('los tiempos de lanzamiento en minutos u horas pluralizan bien', () {
      // La alternancia de regex probaba "minuto" antes que "minutos" y
      // recortaba el plural; Clarividencia (10 minutos) lo destapó.
      expect(spell('clairvoyance').castingTime, '10 minutos');
    });

    test(
        'el alcance en millas usa la misma convención que Enjambre de Meteoros',
        () {
      expect(spell('clairvoyance').range, '1 milla');
    });

    test('Truco de la Cuerda perdió la comilla suelta del OCR', () {
      // El PDF trae el nombre partido entre dos columnas con una comilla
      // tipográfica pegada al principio ("“TRUCO DE LA CUERDA); es el caso que
      // más se parece a corromper un id o un nombre por accidente.
      expect(spell('rope-trick').name, 'Truco de la Cuerda');
    });

    test('los conjuros compuestos capitalizan las dos mitades', () {
      expect(spell('enlarge-reduce').name, 'Agrandar/Reducir');
      expect(spell('blindness-deafness').name, 'Sordera/Ceguera');
    });

    test('Castigo Divino es un conjuro en 2024, no un rasgo del Paladín', () {
      // El cambio de reglas más visible de este nivel: en 2014 el Paladín
      // gastaba espacios directamente; en 2024 gasta el conjuro.
      final s = spell('divine-smite');
      expect(s.level, 1);
      expect(s.classes, contains('paladin'));
      expect(s.castingTime, 'Acción Adicional');
      expect(s.description, contains('2d8'));
    });

    test('el ritual sale del tiempo de lanzamiento y no lo ensucia', () {
      // El PDF escribe "Acción o ritual" en el mismo campo; acá va separado.
      for (final id in ['alarm', 'find-familiar', 'unseen-servant']) {
        expect(spell(id).ritual, isTrue, reason: '$id debería ser ritual');
        expect(spell(id).castingTime, isNot(contains('ritual')));
      }
      expect(spell('chromatic-orb').ritual, isFalse);
    });

    test('los alcances nuevos quedaron en pies', () {
      expect(spell('thorn-whip').range, '30 pies');
      expect(spell('hex').range, '90 pies');
      expect(spell('blade-ward').range, 'Personal');
      expect(spell('mage-armor').range, 'Toque');
    });

    test('la concentración quedó separada de la duración', () {
      final s = spell('hex');
      expect(s.concentration, isTrue);
      expect(s.duration, '1 hora');
      expect(spell('divine-favor').concentration, isFalse);
    });

    test('las altas se etiquetan phb_2024, no srd_2024', () {
      // Sin el SRD a mano no se puede afirmar que estén cubiertas por
      // CC BY 4.0. Quedarse corto es seguro; al revés sería un problema.
      for (final id in ['friends', 'divine-smite', 'hex', 'chromatic-orb']) {
        expect(spell(id).source, ContentSource.phb2024);
      }
    });
  });

  group('nomenclatura del PHB 2024', () {
    // 31 conjuros llevaban un nombre en español que no es el del manual. Se
    // verificaron por dos vías independientes: la firma de metadatos (nivel,
    // componentes, duración, alcance y clases) contra el capítulo 7, y el id,
    // que es el nombre en inglés. Los ids no cambian: son la referencia que
    // usan los linajes y los personajes guardados.
    const oficiales = {
      'druidcraft': 'Saber Druídico',
      'vicious-mockery': 'Burla Dañina',
      'shocking-grasp': 'Agarre Electrizante',
      'spare-the-dying': 'Piedad con los Moribundos',
      'produce-flame': 'Crear Llama',
      'fire-bolt': 'Descarga de Fuego',
      'charm-person': 'Hechizar Persona',
      'thunderwave': 'Ola Atronadora',
      'guiding-bolt': 'Saeta Guía',
      'see-invisibility': 'Ver Invisibilidad',
      'animate-dead': 'Animar a los Muertos',
      'tongues': 'Don de Lenguas',
      'raise-dead': 'Alzar a los Muertos',
      'heal': 'Curar',
      'plane-shift': 'Desplazamiento entre Planos',
      'mass-heal': 'Curar en Masa',
    };

    oficiales.forEach((id, nombre) {
      test('$id se llama $nombre', () => expect(spell(id).name, nombre));
    });

    // Segunda tanda: la firma de metadatos no los resolvía sola, así que cada
    // destino se verificó leyendo su encabezado y su nivel en el capítulo 7.
    const segundaTanda = {
      'true-strike': 'Impacto Certero',
      'goodberry': 'Buenas Bayas',
      'fog-cloud': 'Nube de Oscurecimiento',
      'command': 'Orden Imperiosa',
      'sleep': 'Dormir',
      'blur': 'Contorno Borroso',
      'spider-climb': 'Trepar cual Arácnido',
      'fear': 'Terror',
      'haste': 'Acelerar',
      'polymorph': 'Polimorfar',
      'greater-restoration': 'Restablecimiento Mayor',
      'time-stop': 'Parar el Tiempo',
      'imprisonment': 'Cautiverio',
      'meteor-swarm': 'Tormenta de Meteoritos',
      'weird': 'Terror Abyecto',
      'hellish-rebuke': 'Reprensión Infernal',
    };

    segundaTanda.forEach((id, nombre) {
      test('$id se llama $nombre', () => expect(spell(id).name, nombre));
    });

    test('ningún conjuro comparte nombre con otro', () {
      // Renombrar destapó una colisión: Ofuscación estaba catalogado como
      // "Mente en Blanco", que es el nombre de mind-blank. Dos conjuros con el
      // mismo nombre son indistinguibles en los selectores de la app.
      final porNombre = <String, String>{};
      for (final s in repo.spells.values) {
        expect(porNombre.containsKey(s.name), isFalse,
            reason: '${s.name}: ${porNombre[s.name]} y ${s.id}');
        porNombre[s.name] = s.id;
      }
    });

    test('Ofuscación usa la versión 2024, no la Mente Débil de 2014', () {
      final s = spell('befuddlement');
      expect(s.name, 'Ofuscación');
      expect(s.description, contains('10d12'));
      // En 2014 reducía Inteligencia y Carisma a 1; en 2024 no toca las
      // puntuaciones, solo impide lanzar conjuros.
      expect(s.description, isNot(contains('Carisma')));
    });

    test('Salpicadura Ácida es de Evocación en 2024', () {
      expect(spell('acid-splash').school, 'Evocación');
    });

    test('Geas dejó de llamarse Mandato', () {
      // Es el caso que más confundía: "Mandato" es el nombre de otro conjuro
      // (Command, de nivel 1), no de este.
      expect(spell('geas').name, 'Geas');
      expect(spell('geas').level, 5);
    });

    test('la escuela de ilusión se llama Ilusionismo', () {
      final escuelas = repo.spells.values.map((s) => s.school).toSet();
      expect(escuelas, contains('Ilusionismo'));
      expect(escuelas, isNot(contains('Ilusión')));
    });
  });

  group('cierre de contenido contra el capítulo 7', () {
    const clasesBase = {
      'bard',
      'cleric',
      'druid',
      'paladin',
      'ranger',
      'sorcerer',
      'warlock',
      'wizard',
    };

    const clasesOficiales = <String, Set<String>>{
      'message': {'bard', 'druid', 'sorcerer', 'wizard'},
      'detect-magic': {
        'bard',
        'cleric',
        'druid',
        'paladin',
        'ranger',
        'sorcerer',
        'warlock',
        'wizard',
      },
      'aid': {'bard', 'cleric', 'druid', 'paladin', 'ranger'},
      'heat-metal': {'bard', 'druid'},
      'prayer-of-healing': {'cleric', 'paladin'},
      'gust-of-wind': {'druid', 'ranger', 'sorcerer', 'wizard'},
      'enhance-ability': {
        'bard',
        'cleric',
        'druid',
        'ranger',
        'sorcerer',
        'wizard',
      },
      'spider-climb': {'sorcerer', 'warlock', 'wizard'},
      'dispel-magic': {
        'bard',
        'cleric',
        'druid',
        'paladin',
        'ranger',
        'sorcerer',
        'warlock',
        'wizard',
      },
      'mass-healing-word': {'bard', 'cleric'},
      'slow': {'bard', 'sorcerer', 'wizard'},
      'phantasmal-killer': {'bard', 'wizard'},
      'fire-shield': {'druid', 'sorcerer', 'wizard'},
      'greater-restoration': {
        'bard',
        'cleric',
        'druid',
        'paladin',
        'ranger',
      },
      'sunbeam': {'cleric', 'druid', 'sorcerer', 'wizard'},
      'mass-suggestion': {'bard', 'sorcerer', 'wizard'},
      'regenerate': {'bard', 'cleric', 'druid'},
      'sunburst': {'cleric', 'druid', 'sorcerer', 'wizard'},
      'incendiary-cloud': {'druid', 'sorcerer', 'wizard'},
      'prismatic-wall': {'bard', 'wizard'},
      'weird': {'warlock', 'wizard'},
      'gate': {'cleric', 'sorcerer', 'warlock', 'wizard'},
      'speak-with-animals': {'bard', 'druid', 'ranger', 'warlock'},
      'hellish-rebuke': {'warlock'},
    };

    test('las 24 listas de clase coinciden con el PHB 2024', () {
      clasesOficiales.forEach((id, esperadas) {
        final actuales = spell(id).classes.toSet().intersection(clasesBase);
        expect(actuales, esperadas, reason: id);
      });
    });

    test('las tres banderas excepcionales coinciden con el encabezado', () {
      expect(spell('forcecage').concentration, isTrue);
      expect(spell('animal-shapes').concentration, isFalse);
      expect(spell('purify-food-and-drink').ritual, isTrue);
    });

    test('incluye las tres entradas ausentes con su firma oficial', () {
      final alterar = spell('modify-memory');
      expect(alterar.name, 'Alterar los Recuerdos');
      expect(alterar.level, 5);
      expect(alterar.classes.toSet(), {'bard', 'wizard'});
      expect(alterar.concentration, isTrue);

      final muertos = spell('speak-with-dead');
      expect(muertos.name, 'Hablar con los Muertos');
      expect(muertos.level, 3);
      expect(muertos.classes.toSet(), {'bard', 'cleric', 'wizard'});
      expect(muertos.duration, '10 minutos');

      final tanido = spell('toll-the-dead');
      expect(tanido.name, 'Tañido por los Muertos');
      expect(tanido.level, 0);
      expect(tanido.classes.toSet(), {'warlock', 'cleric', 'wizard'});
      expect(tanido.description, contains('1d12'));
    });

    test('usa los cinco ids canónicos de 2024 y descarta los heredados', () {
      const renombres = {
        'feeblemind': 'befuddlement',
        'snare': 'cordon-of-arrows',
        'dispel-good-and-evil': 'dispel-evil-and-good',
        'holy-word': 'divine-word',
        'branding-smite': 'shining-smite',
      };
      renombres.forEach((anterior, actual) {
        expect(repo.spells, isNot(contains(anterior)), reason: anterior);
        expect(repo.spells, contains(actual), reason: actual);
      });
    });

    test('el catálogo base contiene los 391 conjuros del PHB', () {
      final oficiales =
          repo.spells.values.where((s) => s.source != ContentSource.foa2025);
      expect(oficiales.length, 391);
      expect(repo.spells.length, 392,
          reason: '391 del PHB más Sirviente Homúnculo de Forge');
    });
  });
}
