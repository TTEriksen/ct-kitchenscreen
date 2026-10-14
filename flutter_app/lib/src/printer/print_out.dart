import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models.dart';

// Printing a ticket on a real network printer (ESC/POS over TCP, port 9100).
// The ticket is rebuilt from its stored lines, keeping bold, large, red,
// reversed and alignment, encoded in PC865 so æ, ø and å come out right.

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

const _esc = 0x1b;
const _gs = 0x1d;

/// ESC/POS bytes for one ticket. [copy] adds a heading such as "KOPI 18:42" for reprints.
Uint8List ticketBytes(List<PrintLine> lines, {String? copy}) {
  final b = <int>[_esc, 0x40, _esc, 0x74, 5];
  void line(PrintLine l) {
    b
      ..addAll([_esc, 0x61, l.align == 'center' ? 1 : (l.align == 'right' ? 2 : 0)])
      ..addAll([_esc, 0x45, l.bold || l.big ? 1 : 0])
      ..addAll([_gs, 0x21, l.big ? 0x11 : 0x00])
      ..addAll([_esc, 0x72, l.red ? 1 : 0])
      ..addAll([_gs, 0x42, l.inverse ? 1 : 0])
      ..addAll(encodeCp865(l.text))
      ..add(0x0a);
  }

  if (copy != null) {
    line(PrintLine(text: copy, bold: true, align: 'center', inverse: true));
    line(PrintLine(text: ''));
  }
  lines.forEach(line);
  b.addAll([_esc, 0x40, _esc, 0x64, 4, _gs, 0x56, 0x42, 0x00]); // reset, feed, partial cut
  return Uint8List.fromList(b);
}

Uint8List testPageBytes(String name) {
  final now = DateTime.now();
  final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  return ticketBytes([
    PrintLine(text: 'TESTUDSKRIFT', big: true, align: 'center'),
    PrintLine(text: name, align: 'center'),
    PrintLine(text: ''),
    PrintLine(text: 'Printeren er forbundet.'),
    PrintLine(text: 'Æ Ø Å æ ø å é'),
    PrintLine(text: 'Fed tekst', bold: true),
    PrintLine(text: 'Rød tekst (2-farve printer)', red: true),
    PrintLine(text: 'Kl. $t'),
  ]);
}

/// Sends [bytes] to a network printer. Throws a Danish message the screen can show.
Future<void> sendToPrinter(String host, int port, List<int> bytes) async {
  Socket sock;
  try {
    sock = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
  } on SocketException catch (e) {
    final code = e.osError?.errorCode;
    if (code == 61 || code == 111) throw PrintError('Printeren $host:$port afviser forbindelsen');
    if (code == 65 || code == 113 || code == 51 || code == 101) throw PrintError('Printeren $host kan ikke nås på netværket');
    throw PrintError('Printeren $host:$port svarer ikke');
  }
  try {
    sock.add(bytes);
    await sock.flush().timeout(const Duration(seconds: 5));
    await sock.close().timeout(const Duration(seconds: 5));
  } on TimeoutException {
    throw PrintError('Printeren $host:$port svarer ikke');
  } finally {
    sock.destroy();
  }
}

class PrintError implements Exception {
  PrintError(this.message);
  final String message;
  @override
  String toString() => message;
}
