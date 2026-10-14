// Writes realistic tickets and settings for App Store screenshots into an app
// data folder (used by tool/screenshots.sh on the iPad simulator):
//
//   dart run tool/screenshot_data.dart <folder> <palette> <dark|light> [focus|recall|settings]
import 'dart:convert';
import 'dart:io';

import 'package:ct_kitchenscreen/src/models.dart';
import 'package:ct_kitchenscreen/src/printer/escpos.dart';
import 'package:ct_kitchenscreen/src/printer/parser.dart';

const tickets = [
  // minutes ago, printed text
  (21, 'Bon 1038\nBord 7\n2 pers.\nTjener: Jonas\n--------------------------------\nFORRET\n2 x Rejecocktail\n1 x Oksetartar\n   - uden æggeblomme\n   - ekstra kapers\nAllergi: æg - tartar uden æggeblomme\n'),
  (13, 'Bon 1039\nBord 12\n4 pers.\nTjener: Mette\n--------------------------------\nHOVEDRET\n2 x Wienerschnitzel\n   - 1 uden kapers\n   - ekstra smørsauce\n1 x Stjerneskud\n   - glutenfrit brød (gluten)\n1 x Børnefrikadeller\n   - kun kartofler, ingen sovs\nNote: børneretten først\n'),
  (9, 'Bon 1040\nBord 21\n6 pers.\nTjener: Sofie\n--------------------------------\nFORRET\n6 Dagens suppe\n    plads 3 uden pesto - nøddeallergi\n6 Hjemmebagt brød\nHOVEDRET\n4 Rib-eye 250 g\n    2 rød\n    2 medium\n2 Laks\n    ingen dild\n*** SELSKAB - SERVER SAMLET ***\n'),
  (6, 'BESKED\nFra: Jonas\nBord 12: hold hovedretten 10 min.\nGæsterne venter på to mere.\n'),
  (4, 'TAKE AWAY\nOrdre #1041\nNavn: Hansen\n--------------------------------\n3 x Burger\n    uden løg\n3 x Pommes frites\n1 x Ekstra aioli\n'),
  (2, 'Bon 1042\nBord 3\n3 pers.\nTjener: Jonas\n--------------------------------\nHOVEDRET\n1 x Laks\n    ingen dild\n2 x Kyllingebryst\n3 x Grøn salat\n'),
  (1, 'Bon 1043\nBord 9\n2 pers.\nTjener: Sofie\n--------------------------------\nDESSERT\n2 x Crème brûlée\n1 x Vaniljeis\n    laktosefri\nAllergi: laktose\n'),
];

const finished = [
  (35, 30, 'Bon 1036\nBord 2\n2 pers.\nTjener: Jonas\nFORRET\n2 x Stegt sild\n1 x Rugbrød\n'),
  (32, 25, 'Bon 1037\nBord 14\n5 pers.\nTjener: Sofie\nHOVEDRET\n3 x Hakkebøf\n    bløde løg\n2 x Flæskesteg\n'),
];

void main(List<String> args) {
  final dir = Directory(args[0])..createSync(recursive: true);
  final now = DateTime.now();
  var seq = 0;
  final out = <Map<String, dynamic>>[];
  Ticket make(int minsAgo, String text, {int? doneMinsAgo}) {
    final lines = decodeJob(utf8.encode(text)).single;
    seq++;
    return Ticket(
      id: 'shot-$seq',
      seq: seq,
      receivedAt: now.subtract(Duration(minutes: minsAgo, seconds: 20)),
      doneAt: doneMinsAgo == null ? null : now.subtract(Duration(minutes: doneMinsAgo)),
      from: '192.168.1.20',
      lines: lines,
      parsed: parseTicket(lines),
    );
  }

  for (final (ago, done, text) in finished) {
    out.add(make(ago, text, doneMinsAgo: done).toJson());
  }
  for (final (ago, text) in tickets) {
    out.add(make(ago, text).toJson());
  }
  File('${dir.path}/tickets.json').writeAsStringSync(jsonEncode({'seq': seq, 'tickets': out}));
  final s = Settings(printerName: 'Køkken', palette: args.length > 1 ? args[1] : 'ctpos', themeMode: args.length > 2 ? args[2] : 'dark')
    ..port = 9101
    ..printerEnabled = true
    ..printerHost = '192.168.1.60';
  File('${dir.path}/settings.json').writeAsStringSync(jsonEncode(s.toJson()));
  final view = File('${dir.path}/screenshot_view.txt');
  if (args.length > 3 && args[3] != 'none') {
    view.writeAsStringSync(args[3]);
  } else if (view.existsSync()) {
    view.deleteSync();
  }
  for (final f in ['logo_dark.img', 'logo_light.img']) {
    final l = File('${dir.path}/$f');
    if (l.existsSync()) l.deleteSync();
  }
}
