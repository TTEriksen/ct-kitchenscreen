// Sample print jobs in ESC/POS, encoded in PC865 the way a Nordic till sends them.
// Used by the "Modtag testbon" button and the tests.

const _cp865 = {
  'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'à': 0x85, 'å': 0x86, 'ç': 0x87,
  'ê': 0x88, 'ë': 0x89, 'è': 0x8a, 'Ä': 0x8e, 'Å': 0x8f, 'É': 0x90, 'æ': 0x91, 'Æ': 0x92,
  'ô': 0x93, 'ö': 0x94, 'ò': 0x95, 'û': 0x96, 'ù': 0x97, 'Ö': 0x99, 'Ü': 0x9a, 'ø': 0x9b,
  'Ø': 0x9d, '·': 0xfa, '×': 0x78,
};

List<int> _enc(String text) => [
      for (final r in text.runes) r < 0x80 ? r : (_cp865[String.fromCharCode(r)] ?? 0x3f),
    ];

const _escB = 0x1b;
const _gsB = 0x1d;
const _init = [_escB, 0x40, _escB, 0x74, 5];
List<int> _big(bool on) => [_gsB, 0x21, on ? 0x11 : 0x00];
List<int> _bold(bool on) => [_escB, 0x45, on ? 1 : 0];
List<int> _red(bool on) => [_escB, 0x72, on ? 1 : 0];
List<int> _inv(bool on) => [_gsB, 0x42, on ? 1 : 0];
List<int> _center(bool on) => [_escB, 0x61, on ? 1 : 0];
const _cut = [_escB, 0x64, 4, _gsB, 0x56, 0x01];
List<int> _line(String t) => [..._enc(t), 0x0a];
final _rule = _line('-' * 32);

String _now([int offsetMin = 0]) {
  final d = DateTime.now().add(Duration(minutes: offsetMin));
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

var _counter = 1040;

final List<List<int> Function()> samples = [
  () => [
        ..._init, ..._center(true), ..._big(true), ..._line('KØKKEN'), ..._big(false), ..._center(false),
        ..._line('Bon nr: ${++_counter}'),
        ..._big(true), ..._line('Bord 12'), ..._big(false),
        ..._line('4 pers.'),
        ..._line('Tjener: Mette'),
        ..._line('${_today()} ${_now()}'),
        ..._rule,
        ..._bold(true), ..._line('HOVEDRET'), ..._bold(false),
        ..._big(true), ..._line('2 x Wienerschnitzel'), ..._big(false),
        ..._line('   - 1 uden kapers'),
        ..._line('   - Ekstra smørsauce'),
        ..._big(true), ..._line('1 x Stjerneskud'), ..._big(false),
        ..._red(true), ..._line('   - ALLERGI: Gluten, glutenfrit brød'), ..._red(false),
        ..._big(true), ..._line('1 x Børnefrikadeller'), ..._big(false),
        ..._line('   - Kun kartofler, ingen sovs'),
        ..._rule,
        ..._line('Note: Børneretten først, gerne hurtigt'),
        ..._cut,
      ],
  () => [
        ..._init,
        ..._line('Ordre: ${++_counter}        ${_now()}'),
        ..._big(true), ..._line('BORD 21'), ..._big(false),
        ..._line('Gæster: 6      Tjener: Sofie'),
        ..._rule,
        ..._bold(true), ..._line('FORRET'), ..._bold(false),
        ..._line('6 Dagens suppe'),
        ..._line('    Plads 3 uden pesto - nøddeallergi'),
        ..._line('6 Hjemmebagt brød'),
        ..._bold(true), ..._line('HOVEDRET'), ..._bold(false),
        ..._line('4 Rib-eye 250 g'),
        ..._line('    2 rød'),
        ..._line('    2 medium'),
        ..._line('2 Laks'),
        ..._line('    Ingen dild'),
        ..._rule,
        ..._inv(true), ..._line('*** SELSKAB - SERVER SAMLET ***'), ..._inv(false),
        ..._cut,
      ],
  () => [
        ..._init, ..._center(true), ..._big(true), ..._line('TAKE AWAY'), ..._big(false), ..._center(false),
        ..._line('Ordre #${++_counter}'),
        ..._line('Kl. ${_now()}'),
        ..._line('Navn: Hansen'),
        ..._line('Afhentes ${_now(25)}'),
        ..._rule,
        ..._line('3 x Burger'),
        ..._line('    uden løg'),
        ..._line('3 x Pommes frites'),
        ..._line('1 x Ekstra aioli'),
        ..._cut,
      ],
  () => [
        ..._init, ..._big(true), ..._line('BESKED'), ..._big(false),
        ..._line('Fra: Jonas  ${_now()}'),
        ..._rule,
        ..._line('Bord 12: hold hovedretten 10 min.'),
        ..._line('Gæsterne venter på to mere.'),
        ..._cut,
      ],
  () => [
        ..._init,
        ..._line('Bon ${++_counter}'),
        ..._big(true), ..._line('Bord 9'), ..._big(false),
        ..._line('2 personer  ${_now()}'),
        ..._line('Tjener: Sofie'),
        ..._rule,
        ..._bold(true), ..._line('DESSERT'), ..._bold(false),
        ..._line('2 x Crème brûlée'),
        ..._line('1 x Vaniljeis'),
        ..._red(true), ..._line('    LAKTOSEFRI'), ..._red(false),
        ..._cut,
      ],
];

var _next = 0;
List<int> nextSample() => samples[_next++ % samples.length]();
