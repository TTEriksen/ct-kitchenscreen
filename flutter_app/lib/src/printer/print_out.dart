import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models.dart';

// Printing a ticket on a real network printer (ESC/POS over TCP, port 9100).
//
// Before printing, the printer is asked about itself on the same connection:
// paper and cover status (DLE EOT) and maker and model (GS I). The model gives
// the paper width; the ticket is then laid out again for exactly that many
// characters per line, so it uses the whole width and no line runs over.
// Same rules as the web version's server/print.js.

const _cp865 = {
  'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'à': 0x85, 'å': 0x86, 'ç': 0x87,
  'ê': 0x88, 'ë': 0x89, 'è': 0x8a, 'ï': 0x8b, 'î': 0x8c, 'ì': 0x8d, 'Ä': 0x8e, 'Å': 0x8f,
  'É': 0x90, 'æ': 0x91, 'Æ': 0x92, 'ô': 0x93, 'ö': 0x94, 'ò': 0x95, 'û': 0x96, 'ù': 0x97,
  'ÿ': 0x98, 'Ö': 0x99, 'Ü': 0x9a, 'ø': 0x9b, '£': 0x9c, 'Ø': 0x9d, 'á': 0xa0, 'í': 0xa1,
  'ó': 0xa2, 'ú': 0xa3, 'ñ': 0xa4, 'Ñ': 0xa5, '¤': 0xaf, '½': 0xab, '¼': 0xac, '°': 0xf8,
  '·': 0xfa, '×': 0x78, '–': 0x2d, '—': 0x2d, '‘': 0x27, '’': 0x27, '“': 0x22, '”': 0x22, '…': 0x2e,
};

List<int> encodeCp865(String text) => [
      for (final r in text.runes) r < 0x80 ? r : (_cp865[String.fromCharCode(r)] ?? 0x3f),
    ];

// ---------- Paper width ----------

/// A printer's width: [cols] Font A characters per line, [dots] printable dots (0 = impact printer).
class PaperProfile {
  const PaperProfile(this.paper, this.cols, this.dots, [this.source = 'setting']);
  final String paper;
  final int cols;
  final int dots;

  /// 'setting' (chosen by the user), 'printer' (from its model) or 'fallback'.
  final String source;

  PaperProfile withSource(String s) => PaperProfile(paper, cols, dots, s);
}

const papers = {
  '80-48': PaperProfile('80 mm', 48, 576),
  '80-42': PaperProfile('80 mm', 42, 512),
  '58-32': PaperProfile('58 mm', 32, 384),
};

/// Used when the printer does not say what it is: fits every 80 mm printer.
const fallbackPaper = PaperProfile('80 mm', 42, 512, 'fallback');

final _models = <(RegExp, PaperProfile)>[
  (RegExp(r'TM-?T88', caseSensitive: false), papers['80-42']!),
  (RegExp(r'TM-?(m10|P20|P60|T20.*58|L90.*58)', caseSensitive: false), papers['58-32']!),
  (RegExp(r'TM-?U2\d\d', caseSensitive: false), const PaperProfile('76 mm', 40, 0)),
  (RegExp(r'TM-?(T20|T70|T81|T82|T83|T90|T100|m30|m50|L90|H6000)', caseSensitive: false), papers['80-48']!),
  (RegExp(r'(TSP1\d\d|TSP6\d\d|TSP7\d\d|mC-Print3|TSP143)', caseSensitive: false), papers['80-48']!),
  (RegExp(r'(mC-Print2|SM-[LST]2|TSP6.*58)', caseSensitive: false), papers['58-32']!),
  (RegExp(r'(SRP-?3\d\d|SRP-?Q3|RP-?F10|RP-?33)', caseSensitive: false), papers['80-48']!),
];

PaperProfile? profileForModel(String? model) {
  if (model == null || model.isEmpty) return null;
  for (final (re, p) in _models) {
    if (re.hasMatch(model)) return p;
  }
  return null;
}

/// The user's choice, else what the printer told us, else the safe fallback.
PaperProfile chooseProfile(String setting, PrinterInfo info) {
  final chosen = papers[setting];
  if (chosen != null) return chosen.withSource('setting');
  final fromModel = profileForModel(info.model);
  if (fromModel != null) return fromModel.withSource('printer');
  return fallbackPaper;
}

/// What the printer said about itself.
class PrinterInfo {
  bool responds = false;
  bool paperOut = false;
  bool coverOpen = false;
  String? maker;
  String? model;

  String get name => [maker, model].whereType<String>().join(' ');
}

// ---------- Laying the ticket out for the printer's width ----------

final _rule = RegExp(r'^[\s\-=_*~.#+]+$');

/// Splits text into pieces of at most [width] characters, at spaces where possible.
List<String> wrapWords(String text, int width) {
  final out = <String>[];
  var rest = text;
  while (rest.length > width) {
    var cut = rest.lastIndexOf(' ', width);
    if (cut < width * .4) cut = width; // no good space: cut the word
    out.add(rest.substring(0, cut).trimRight());
    rest = rest.substring(cut).trimLeft();
  }
  if (rest.isNotEmpty || out.isEmpty) out.add(rest);
  return out;
}

PrintLine _with(PrintLine l, String text) =>
    PrintLine(text: text, bold: l.bold, big: l.big, red: l.red, inverse: l.inverse, underline: l.underline, align: l.align);

/// Lays printed lines out again for a printer with [cols] characters per line:
/// rules fill the width, "left … right" lines are spread to both edges, long
/// lines wrap with a hanging indent, and double-size lines count double.
List<PrintLine> layoutLines(List<PrintLine> lines, int cols) {
  final out = <PrintLine>[];
  for (final l in lines) {
    final text = l.text.trimRight();
    final width = math.max(8, l.big ? cols ~/ 2 : cols);
    void keep(String t) => out.add(_with(l, t));

    if (text.trim().isEmpty) {
      keep('');
      continue;
    }

    // Separator lines: redraw across the whole width.
    if (_rule.hasMatch(text) && text.trim().length >= 6) {
      keep(text.trim()[0] * width);
      continue;
    }

    // "Left      right" (two parts with a wide gap): left edge and right edge.
    final two = l.align == 'center' ? null : RegExp(r'^(\s*\S(?:.*?\S)?)\s{3,}(\S(?:.*\S)?)$').firstMatch(text);
    if (two != null && two.group(2)!.length <= width ~/ 2) {
      final left = two.group(1)!;
      final right = two.group(2)!;
      if (left.length + 1 + right.length <= width) {
        keep(left + ' ' * (width - left.length - right.length) + right);
      } else {
        wrapWords(left, width).forEach(keep);
        keep(' ' * (width - right.length) + right);
      }
      continue;
    }

    if (text.length <= width) {
      keep(text);
      continue;
    }

    // Too long: wrap, indenting the continuation under the dish name or the line's own indent.
    final lead = text.length - text.trimLeft().length;
    final item = RegExp(r'^(\s*\d{1,3}\s*(?:x|×|stk\.?)?\s+)', caseSensitive: false).firstMatch(text);
    final hang = math.min(width ~/ 2, item != null ? item.group(1)!.length : lead);
    final words = wrapWords(text.trim(), width - lead);
    keep(' ' * lead + words.first);
    final tail = words.skip(1).join(' ');
    if (tail.isNotEmpty) {
      for (final w in wrapWords(tail, width - hang)) {
        keep(' ' * hang + w);
      }
    }
  }
  return out;
}

// ---------- ESC/POS ----------

const _esc = 0x1b;
const _gs = 0x1d;
const _dle = 0x10;

/// ESC/POS bytes for one ticket, laid out for [profile]. [copy] adds a heading such as "KOPI 18:42".
Uint8List ticketBytes(List<PrintLine> lines, {String? copy, PaperProfile profile = fallbackPaper}) {
  final b = <int>[_esc, 0x40, _esc, 0x74, 5];
  // Use the whole paper: no left margin, print area = the printer's full width.
  if (profile.dots > 0) b.addAll([_gs, 0x4c, 0, 0, _gs, 0x57, profile.dots & 255, profile.dots >> 8]);
  final all = [
    if (copy != null) ...[PrintLine(text: copy, bold: true, align: 'center', inverse: true), PrintLine(text: '')],
    ...lines,
  ];
  for (final l in layoutLines(all, profile.cols)) {
    b
      ..addAll([_esc, 0x61, l.align == 'center' ? 1 : (l.align == 'right' ? 2 : 0)])
      ..addAll([_esc, 0x45, l.bold || l.big ? 1 : 0])
      ..addAll([_gs, 0x21, l.big ? 0x11 : 0x00])
      ..addAll([_esc, 0x72, l.red ? 1 : 0])
      ..addAll([_gs, 0x42, l.inverse ? 1 : 0])
      ..addAll(encodeCp865(l.text))
      ..add(0x0a);
  }
  b.addAll([_esc, 0x40, _esc, 0x64, 4, _gs, 0x56, 0x42, 0x00]); // reset, feed, partial cut
  return Uint8List.fromList(b);
}

List<PrintLine> testPageLines(String name, PaperProfile profile, PrinterInfo info) {
  final now = DateTime.now();
  final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final ruler = ('1234567890' * (profile.cols ~/ 10 + 1)).substring(0, profile.cols);
  return [
    PrintLine(text: 'TESTUDSKRIFT', big: true, align: 'center'),
    PrintLine(text: name, align: 'center'),
    PrintLine(text: '-' * 10),
    PrintLine(text: 'Printer:   ${info.name.isEmpty ? 'ukendt model' : info.name}'),
    PrintLine(text: 'Bredde:    ${profile.paper} · ${profile.cols} tegn pr. linje'),
    PrintLine(text: ruler),
    PrintLine(text: 'Æ Ø Å æ ø å é'),
    PrintLine(text: 'Fed tekst', bold: true),
    PrintLine(text: 'Rød tekst (2-farve printer)', red: true),
    PrintLine(text: 'Kl.${' ' * 5}$t'),
  ];
}

// ---------- Talking to the printer ----------

class PrintError implements Exception {
  PrintError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One connection to a printer: ask it questions, then send the job.
class _Conn {
  _Conn(this.sock) {
    sock.listen((d) {
      _buf.addAll(d);
      _check?.call();
    }, onError: (_) {}, onDone: () {});
  }

  final Socket sock;
  final _buf = <int>[];
  void Function()? _check;

  /// Sends a query and waits for a reply that [parse] accepts (non-null), or null after [ms].
  Future<T?> ask<T>(List<int> bytes, T? Function(List<int>) parse, {int ms = 700}) {
    _buf.clear();
    final c = Completer<T?>();
    final timer = Timer(Duration(milliseconds: ms), () {
      if (!c.isCompleted) c.complete(null);
    });
    _check = () {
      final v = parse(_buf);
      if (v != null && !c.isCompleted) {
        timer.cancel();
        c.complete(v);
      }
    };
    sock.add(bytes);
    return c.future.whenComplete(() => _check = null);
  }
}

int? _statusByte(List<int> b) => b.isNotEmpty && (b[0] & 0x93) == 0x12 ? b[0] : null;

String? _infoString(List<int> b) {
  final start = b.indexOf(0x5f);
  if (start < 0) return null;
  final end = b.indexOf(0x00, start);
  if (end < 0) return null;
  return String.fromCharCodes(b.sublist(start + 1, end)).trim();
}

Future<PrinterInfo> _probe(_Conn c) async {
  final info = PrinterInfo();
  final paper = await c.ask([_dle, 0x04, 4], _statusByte);
  if (paper == null) return info; // no real-time replies: nothing more to learn
  info.responds = true;
  info.paperOut = paper & 0x60 == 0x60;
  final offline = await c.ask([_dle, 0x04, 2], _statusByte);
  if (offline != null) info.coverOpen = offline & 0x04 == 0x04;
  final maker = await c.ask([_gs, 0x49, 0x42], _infoString);
  final model = await c.ask([_gs, 0x49, 0x43], _infoString);
  info.maker = (maker?.isEmpty ?? true) ? null : maker;
  info.model = (model?.isEmpty ?? true) ? null : model;
  return info;
}

Future<Socket> _connect(String host, int port) async {
  try {
    return await Socket.connect(host, port, timeout: const Duration(seconds: 5));
  } on SocketException catch (e) {
    final code = e.osError?.errorCode;
    if (code == 61 || code == 111) throw PrintError('Printeren $host:$port afviser forbindelsen');
    if (code == 65 || code == 113 || code == 51 || code == 101) throw PrintError('Printeren $host kan ikke nås på netværket');
    throw PrintError('Printeren $host:$port svarer ikke');
  }
}

/// Connects, asks the printer what it is, lays the job out for its width with
/// [build] and prints it. Returns the width used and what the printer said.
Future<(PaperProfile, PrinterInfo)> printJob(
  String host,
  int port,
  String paperSetting,
  List<int> Function(PaperProfile, PrinterInfo) build,
) async {
  final sock = await _connect(host, port);
  try {
    final conn = _Conn(sock);
    final info = await _probe(conn);
    if (info.paperOut) throw PrintError('Printeren mangler papir');
    if (info.coverOpen) throw PrintError('Printerens låg er åbent');
    final profile = chooseProfile(paperSetting, info);
    sock.add(build(profile, info));
    await sock.flush().timeout(const Duration(seconds: 5));
    await sock.close().timeout(const Duration(seconds: 5));
    return (profile, info);
  } on TimeoutException {
    throw PrintError('Printeren $host:$port svarer ikke');
  } finally {
    Timer(const Duration(seconds: 1), sock.destroy);
  }
}
