import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  Character character({
    String race = 'human',
    String klass = 'fighter',
    String background = 'hermit',
    String? subclass,
    int level = 1,
    Map<String, List<String>> choices = const {},
  }) =>
      Character(
        id: 'tool-probe',
        name: 'Prueba',
        raceId: race,
        classId: klass,
        backgroundId: background,
        subclassId: subclass,
        level: level,
        assignedScores: {for (final ability in Ability.values) ability: 12},
        hpPerLevel: List.filled(level, 6),
        proficiencyChoices: choices,
      );

  ProficiencyChoiceSlot slot(ComputedSheet sheet, String groupId) =>
      sheet.proficiencyChoiceSlots.singleWhere((s) => s.groupId == groupId);

  test('los trasfondos expanden juegos, instrumentos y herramientas', () {
    final gaming = slot(
      compiler.compile(character(background: 'soldier')),
      'background:soldier:gaming-set:proficiency',
    );
    expect(gaming.tools, gamingSetProficiencyIds);
    expect(gaming.tools, isNot(contains('gaming-set')));

    final instruments = slot(
      compiler.compile(character(background: 'entertainer')),
      'background:entertainer:musical-instrument:proficiency',
    );
    expect(instruments.tools, musicalInstrumentProficiencyIds);

    final artisan = slot(
      compiler.compile(character(background: 'artisan')),
      'background:artisan:artisans-tools:proficiency',
    );
    expect(artisan.tools, artisanToolProficiencyIds);
  });

  test('Artifice y Fabricante ofrecen herramientas de artesano', () {
    final artificer = compiler.compile(character(klass: 'artificer'));
    expect(
      slot(artificer, 'class:artificer:artisan-tool').tools,
      artisanToolProficiencyIds,
    );
    expect(artificer.toolProficiencies, isNot(contains('artisans-tools')));

    final crafter = compiler.compile(character(background: 'artisan'));
    final crafterSlot = slot(crafter, 'feat:crafter:tools');
    expect(crafterSlot.count, 3);
    expect(crafterSlot.skills, isEmpty);
    expect(crafterSlot.tools, artisanToolProficiencyIds);
  });

  test('Khoravar permite una habilidad o herramienta reemplazable', () {
    final khoravar = slot(
      compiler.compile(character(race: 'khoravar')),
      'race:khoravar:skill-versatility',
    );
    expect(khoravar.count, 1);
    expect(khoravar.skills, Skill.allIds);
    expect(khoravar.tools, toolProficiencyIds);
    expect(khoravar.replaceable, isTrue);
  });

  test('Forjado conserva la habilidad y agrega una herramienta', () {
    final warforged = slot(
      compiler.compile(character(race: 'warforged')),
      'race:warforged:specialized-design-tool',
    );
    expect(warforged.skills, isEmpty);
    expect(warforged.tools, toolProficiencyIds);
    expect(repo.race('warforged')!.skillChoiceCount, 1);
  });

  test('Maestro de Batalla separa habilidad y herramienta', () {
    final sheet = compiler.compile(
      character(subclass: 'battle-master', level: 3),
    );
    final skill = slot(sheet, 'subclass:battle-master:skill');
    final tool = slot(sheet, 'subclass:battle-master:artisan-tool');
    expect(skill.skills, Skill.allIds);
    expect(skill.tools, isEmpty);
    expect(tool.skills, isEmpty);
    expect(tool.tools, artisanToolProficiencyIds);
  });

  test('subclase de Artifice ofrece reemplazo si ya tenia la herramienta', () {
    const backgroundGroup =
        'background:artisan:artisans-tools:proficiency';
    final sheet = compiler.compile(
      character(
        klass: 'artificer',
        subclass: 'armorer',
        background: 'artisan',
        level: 3,
        choices: const {
          backgroundGroup: ['smiths-tools'],
        },
      ),
    );
    final armorer = slot(sheet, 'subclass:armorer:smiths-tools');
    expect(armorer.tools, isNot(contains('smiths-tools')));
    expect(armorer.tools, contains('woodcarvers-tools'));
  });

  test('el reemplazo respeta una herramienta heredada', () {
    final sheet = compiler.compile(
      character(
        klass: 'artificer',
        subclass: 'armorer',
        level: 3,
      ).copyWith(chosenProficiencies: const ['smiths-tools']),
    );

    expect(
      slot(sheet, 'class:artificer:artisan-tool').chosen,
      ['smiths-tools'],
    );
    final replacement = slot(sheet, 'subclass:armorer:smiths-tools');
    expect(replacement.chosen, isEmpty);
    expect(replacement.tools, isNot(contains('smiths-tools')));
    expect(replacement.tools, contains('woodcarvers-tools'));
  });

  test('la migracion v8 conserva elecciones antiguas sin asignarlas sola', () {
    final json = character().toJson()
      ..['schemaVersion'] = 8
      ..remove('proficiencyChoices')
      ..['chosenProficiencies'] = ['arcana'];
    final migrated = Character.fromJson(json);
    expect(migrated.chosenProficiencies, ['arcana']);
    expect(migrated.proficiencyChoices, isEmpty);
    expect(migrated.toJson()['schemaVersion'], 9);
  });
}
