// Pasa a voseo rioplatense la prosa de los catálogos de `lib/assets/srd_2024/`.
//
//     dart tool/apply_voseo.dart
//
// Parchea, no genera: `generate_magic_items.py` copia el texto del SRD en
// español, que está en tuteo, y este pasa después. Es idempotente —las formas
// de voseo no vuelven a coincidir con nada—, así que se puede correr sobre
// todo el catálogo cada vez. `content_integrity_test` falla si vuelve una forma
// de tuteo inequívoca.
//
// Qué cambia y qué no:
// - El presente de tú pasa a vos («puedes» → «podés») y «ti»/«tú» a «vos».
// - El plural de vosotros pasa a ustedes, que en rioplatense es de tercera
//   («tenéis» → «tienen»). Las frases con pronombre («os mováis») van enteras
//   en [_frases], porque cambia más de una palabra.
// - El subjuntivo queda («cuando puedas»): es el mismo en voseo.
// - Los imperativos se tocan solo donde son inequívocos. «tira» o «elige»
//   sueltos también son tercera persona («tu GM elige»): van como frase, o en
//   mayúscula al empezar una oración ([_mayusculas]).
// - No entran las palabras que además son sustantivo o adjetivo en el
//   catálogo: «cargas», «muestras», «guardas», «cortas», «activas». Donde son
//   verbo van como frase.
//
// Trabaja sobre el texto del archivo, no sobre el JSON reserializado, para no
// tocar el formato de cada catálogo. Las claves están en inglés y los ids son
// slugs con guiones, que la regex excluye a los dos lados.

import 'dart:io';

/// Presente de tú → vos, y vosotros → ustedes. Sin mayúscula: se respeta la
/// del original.
const _palabras = <String, String>{
  // vosotros → ustedes
  'tenéis': 'tienen', 'estéis': 'estén', 'podéis': 'pueden',
  'obtenéis': 'obtienen', 'hacéis': 'hacen', 'recuperáis': 'recuperan',
  'ganáis': 'ganan', 'superéis': 'superen', 'acertáis': 'aciertan',
  'tendréis': 'tendrán', 'sumáis': 'suman', 'causáis': 'causan',
  'dejáis': 'dejan', 'seáis': 'sean', 'hagáis': 'hagan', 'muráis': 'mueran',
  // pronombres
  'tú': 'vos', 'ti': 'vos',
  // presente de tú → vos
  'abandonas': 'abandonás', 'abres': 'abrís', 'abusas': 'abusás',
  'acabas': 'acabás', 'aceptas': 'aceptás', 'aciertas': 'acertás',
  'adoptas': 'adoptás', 'afectas': 'afectás', 'agarras': 'agarrás',
  'agitas': 'agitás', 'alejas': 'alejás', 'anulas': 'anulás',
  'aplicas': 'aplicás', 'aprendes': 'aprendés', 'aprisionas': 'aprisionás',
  'arrojas': 'arrojás', 'aterrizas': 'aterrizás', 'atraviesas': 'atravesás',
  'aumentas': 'aumentás', 'balanceas': 'balanceás', 'controlas': 'controlás',
  'embrazas': 'embrazás', 'logras': 'lográs', 'meditas': 'meditás',
  'añades': 'añadís', 'bajas': 'bajás', 'bebes': 'bebés',
  'beneficias': 'beneficiás', 'caes': 'caés', 'calientas': 'calentás',
  'cambias': 'cambiás', 'canalizas': 'canalizás', 'cancelas': 'cancelás',
  'colapsas': 'colapsás', 'concentras': 'concentrás', 'conoces': 'conocés',
  'consagras': 'consagrás', 'conservas': 'conservás',
  'consigues': 'conseguís', 'conviertes': 'convertís',
  'convocas': 'convocás', 'corres': 'corrés', 'creas': 'creás',
  'cubres': 'cubrís', 'cumples': 'cumplís', 'curas': 'curás',
  'dañas': 'dañás', 'debes': 'debés', 'decides': 'decidís',
  'dedicas': 'dedicás', 'dejas': 'dejás', 'derribas': 'derribás',
  'desapareces': 'desaparecés', 'desatas': 'desatás',
  'descansas': 'descansás', 'desconvocas': 'desconvocás',
  'desencadenas': 'desencadenás', 'desenvainas': 'desenvainás',
  'destierras': 'desterrás', 'detienes': 'detenés',
  'determinas': 'determinás', 'devuelves': 'devolvés',
  'dibujas': 'dibujás', 'distribuyes': 'distribuís', 'drenas': 'drenás',
  'duplicas': 'duplicás', 'eliges': 'elegís', 'eliminas': 'eliminás',
  'empiezas': 'empezás', 'empleas': 'empleás', 'empuñas': 'empuñás',
  'encoges': 'encogés', 'encuentras': 'encontrás', 'entiendes': 'entendés',
  'entras': 'entrás', 'envenenas': 'envenenás', 'envías': 'enviás',
  'eres': 'sos', 'esculpes': 'esculpís', 'esquivas': 'esquivás',
  'estabilizas': 'estabilizás', 'fallas': 'fallás', 'ganas': 'ganás',
  'gastas': 'gastás', 'haces': 'hacés', 'imbuyes': 'imbuís',
  'impactas': 'impactás', 'impones': 'imponés', 'infliges': 'infligís',
  'inspiras': 'inspirás', 'intercambias': 'intercambiás',
  'interrumpes': 'interrumpís', 'invocas': 'invocás', 'lanceas': 'lanceás',
  'lanzas': 'lanzás', 'levantas': 'levantás', 'llevas': 'llevás',
  'maldices': 'maldecís', 'manifiestas': 'manifestás',
  'manipulas': 'manipulás', 'mantienes': 'mantenés', 'marcas': 'marcás',
  'matas': 'matás', 'mientes': 'mentís', 'metes': 'metés',
  'miras': 'mirás', 'montas': 'montás', 'mueres': 'morís',
  'mueves': 'movés', 'necesitas': 'necesitás', 'niegas': 'negás',
  'nombras': 'nombrás', 'observas': 'observás', 'obtienes': 'obtenés',
  'ordenas': 'ordenás', 'otorgas': 'otorgás', 'oyes': 'oís',
  'pasas': 'pasás', 'percibes': 'percibís', 'perfeccionas': 'perfeccionás',
  'permaneces': 'permanecés', 'permites': 'permitís', 'pierdes': 'perdés',
  'pintas': 'pintás', 'pones': 'ponés', 'portas': 'portás',
  'posees': 'poseés', 'potencias': 'potenciás', 'pretendes': 'pretendés',
  'pronuncias': 'pronunciás', 'provocas': 'provocás', 'puedes': 'podés',
  'quedas': 'quedás', 'quitas': 'quitás', 'reaccionas': 'reaccionás',
  'realizas': 'realizás', 'reanimas': 'reanimás', 'recibes': 'recibís',
  'recuperas': 'recuperás', 'reduces': 'reducís', 'reemplazas': 'reemplazás',
  'regeneras': 'regenerás', 'reparas': 'reparás', 'repartes': 'repartís',
  'repites': 'repetís', 'restauras': 'restaurás', 'reubicas': 'reubicás',
  'revives': 'revivís', 'riegas': 'regás', 'robas': 'robás',
  'sabes': 'sabés', 'sacas': 'sacás', 'sacudes': 'sacudís',
  'sintonizas': 'sintonizás', 'soplas': 'soplás', 'sostienes': 'sostenés',
  'sueltas': 'soltás', 'sufres': 'sufrís', 'sujetas': 'sujetás',
  'sumas': 'sumás', 'superas': 'superás', 'susurras': 'susurrás',
  'teletransportas': 'teletransportás', 'terminas': 'terminás',
  'tienes': 'tenés', 'tiras': 'tirás', 'tocas': 'tocás',
  'transformas': 'transformás', 'transportas': 'transportás',
  'usas': 'usás', 'utilizas': 'utilizás', 'vuelas': 'volás',
  'vuelcas': 'volcás', 'vuelves': 'volvés',
};

/// Imperativos que en minúscula también son tercera persona («tu GM elige»),
/// pero al empezar una oración solo le hablan al jugador.
const _mayusculas = <String, String>{
  'Elige': 'Elegí',
  'Tira': 'Tirá',
  'Consulta': 'Consultá',
  'Aplica': 'Aplicá',
};

/// Frases exactas: cambian el pronombre junto con el verbo, o desambiguan un
/// imperativo por su contexto. Van antes que las palabras.
const _frases = <(String, String)>[
  ('os mováis', 'se muevan'),
  ('podéis comunicaros', 'pueden comunicarse'),
  ('Para entenderos', 'Para entenderse'),
  ('evitáis o reducís', 'evitan o reducen'),
  ('os desplazáis', 'se desplazan'),
  ('La criatura y tú os podréis', 'La criatura y vos se podrán'),
  (
    'la pesadilla y tú os transportaréis',
    'la pesadilla y vos se transportarán'
  ),
  // «os» es «a vos y a lo que llevás»; el resto de la frase ya nombra a los dos.
  ('°C o menos no os', '°C o menos no te'),
  ('proyectáis vuestra forma astral', 'proyectan su forma astral'),
  ('os fundís', 'se funden'),
  ('no sufrís daño si superáis', 'no sufren daño si superan'),
  ('a serviros', 'a servirte'),
  (
    'o localizáis criaturas pensantes que no veis',
    'o localizás criaturas pensantes que no ves'
  ),
  ('si os desviáis de él', 'si te desviás de él'),
  ('igual o menor al vuestro', 'igual o menor al tuyo'),
  ('os teletransportáis', 'se teletransportan'),
  // «Cobras vida» no es español: el conjuro da vida.
  ('Cobras vida hasta diez objetos', 'Das vida a hasta diez objetos'),
  // Imperativos en minúscula, reconocibles por lo que los rodea.
  (', tira ', ', tirá '),
  (', haz', ', hacé'),
  ('(consulta ', '(consultá '),
  ('consulta el destino', 'consultá el destino'),
  ('consúltalas', 'consultalas'),
  ('(usa tu', '(usá tu'),
  ('y añade tu modificador', 'y añadí tu modificador'),
  ('toma el resultado máximo', 'tomá el resultado máximo'),
  ('elige una al azar', 'elegí una al azar'),
];

/// Los sustantivos que el reemplazo por palabra convierte en verbo. Se
/// devuelven después, en su contexto exacto.
const _deshacer = <(String, String)>[
  ('bastones o lanzás', 'bastones o lanzas'),
  ('causás dignas', 'causas dignas'),
];

/// Sin letra ni guion a los lados. En el archivo los saltos de línea están
/// escritos como `\n`, y esa «n» no cuenta: si no, ninguna palabra que
/// empiece un renglón del PDF se convertiría.
const _antes = r'(?<!(?<!\\)[\p{L}-])';
const _despues = r'(?![\p{L}-])';

String voseo(String text) {
  for (final (a, b) in _frases) {
    text = text.replaceAll(a, b);
  }
  final palabras = RegExp(
    '$_antes(${_palabras.keys.join('|')})$_despues',
    caseSensitive: false,
    unicode: true,
  );
  text = text.replaceAllMapped(palabras, (m) {
    final original = m[0]!;
    final out = _palabras[original.toLowerCase()]!;
    return original[0] == original[0].toUpperCase()
        ? out[0].toUpperCase() + out.substring(1)
        : out;
  });
  final mayusculas = RegExp(
    '$_antes(${_mayusculas.keys.join('|')})$_despues',
    unicode: true,
  );
  text = text.replaceAllMapped(mayusculas, (m) => _mayusculas[m[0]!]!);
  for (final (a, b) in _deshacer) {
    text = text.replaceAll(a, b);
  }
  return text;
}

void main() {
  final dir = Directory('lib/assets/srd_2024');
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    // El bestiario habla de las criaturas en tercera persona, y lo escribe su
    // propio generador.
    if (!name.endsWith('.json') || name == 'creatures.json') continue;
    final before = file.readAsStringSync();
    final after = voseo(before);
    if (after != before) {
      file.writeAsStringSync(after);
      stdout.writeln('$name: actualizado');
    }
  }
}
