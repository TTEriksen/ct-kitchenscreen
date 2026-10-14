import 'dart:io';

import 'package:ct_kitchenscreen/src/models.dart';
import 'package:ct_kitchenscreen/src/printer/escpos.dart';
import 'package:ct_kitchenscreen/src/printer/parser.dart';
import 'package:ct_kitchenscreen/src/printer/print_out.dart';
import 'package:ct_kitchenscreen/src/printer/samples.dart';
import 'package:ct_kitchenscreen/src/ui/theme.dart';
import 'package:ct_kitchenscreen/src/ui/ticket_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Ticket sampleTicket() {
  final lines = decodeJob(samples[0]()).single;
  return Ticket(id: 'a', seq: 1, receivedAt: DateTime.now(), from: '192.168.1.20', lines: lines, parsed: parseTicket(lines));
}

void main() {
  test('a printed ticket decodes back to the same lines and styles', () {
    final page = decodeJob(samples[0]()).single;
    final again = decodeJob(ticketBytes(page)).single;
    // Same content; separators are redrawn to the full width.
    String norm(String t) => RegExp(r'^[-=_*]+$').hasMatch(t.trim()) ? '---' : t.trim();
    expect(again.map((l) => norm(l.text)), page.map((l) => norm(l.text)));
    expect(again.firstWhere((l) => l.text.contains('ALLERGI')).red, isTrue);
    expect(again.firstWhere((l) => l.text == 'KØKKEN').big, isTrue);
  });

  test('a reprint starts with the copy heading', () {
    final again = decodeJob(ticketBytes(decodeJob(samples[2]()).single, copy: 'KOPI 18:42')).single;
    expect(again.first.text, 'KOPI 18:42');
    expect(again.first.inverse, isTrue);
  });

  test('no printed line is wider than the paper, at any width', () {
    for (final cols in [32, 42, 48]) {
      for (final make in samples) {
        final page = decodeJob(make()).single;
        final printed = decodeJob(ticketBytes(page, copy: 'KOPI 18:42', profile: PaperProfile('t', cols, 0))).single;
        for (final l in printed) {
          final width = l.big ? cols ~/ 2 : cols;
          expect(l.text.length, lessThanOrEqualTo(width), reason: '$cols cols: "${l.text}"');
        }
      }
    }
  });

  test('separators fill the width, left/right lines reach both edges, long lines wrap under the name', () {
    final out = layoutLines([
      PrintLine(text: '-' * 32),
      PrintLine(text: 'Ordre: 1042        18:05'),
      PrintLine(text: '2 x Pariserbøf med alt tilbehør, rødbeder, peberrod og kapers'),
    ], 48);
    expect(out[0].text, '-' * 48);
    expect(out[1].text.length, 48);
    expect(out[1].text.endsWith('18:05'), isTrue);
    expect(out[3].text.startsWith('    '), isTrue);
    expect(out.every((l) => l.text.length <= 48), isTrue);
  });

  test('known models give their width and the setting wins', () {
    expect(profileForModel('TM-T88V')!.cols, 42);
    expect(profileForModel('TM-T20III')!.cols, 48);
    expect(profileForModel('TM-m10')!.cols, 32);
    expect(profileForModel('Mystery 3000'), isNull);
    expect(chooseProfile('58-32', PrinterInfo()..model = 'TM-T88V').cols, 32);
    expect(chooseProfile('auto', PrinterInfo()).source, 'fallback');
  });

  Future<(ServerSocket, List<List<int>>)> fakePrinter({String model = 'TM-T20III', bool paperOut = false, bool answers = true}) async {
    final jobs = <List<int>>[];
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((s) {
      final got = <int>[];
      s.listen((d) {
        got.addAll(d);
        if (!answers) return;
        for (var i = 0; i < d.length - 2; i++) {
          if (d[i] == 0x10 && d[i + 1] == 0x04) s.add([d[i + 2] == 4 && paperOut ? 0x72 : 0x12]);
          if (d[i] == 0x1d && d[i + 1] == 0x49 && d[i + 2] == 0x42) s.add([0x5f, ...'EPSON'.codeUnits, 0]);
          if (d[i] == 0x1d && d[i + 1] == 0x49 && d[i + 2] == 0x43) s.add([0x5f, ...model.codeUnits, 0]);
        }
      }, onDone: () => jobs.add(got));
    });
    return (server, jobs);
  }

  List<int> build(PaperProfile p, PrinterInfo i) => ticketBytes(testPageLines('Test', p, i), profile: p);

  test('asks the printer its model and prints at its width', () async {
    final (server, jobs) = await fakePrinter();
    final (profile, info) = await printJob('127.0.0.1', server.port, 'auto', build);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await server.close();
    expect(info.model, 'TM-T20III');
    expect((profile.cols, profile.source), (48, 'printer'));
    expect(decodeJob(jobs.single).single.any((l) => l.text == '123456789012345678901234567890123456789012345678'), isTrue);
  });

  test('stops when out of paper, falls back when silent, reports a missing printer', () async {
    final (out, _) = await fakePrinter(paperOut: true);
    await expectLater(printJob('127.0.0.1', out.port, 'auto', build), throwsA(isA<PrintError>()));
    await out.close();

    final (silent, jobs) = await fakePrinter(answers: false);
    final (profile, _) = await printJob('127.0.0.1', silent.port, 'auto', build);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await silent.close();
    expect((profile.cols, profile.source), (42, 'fallback'));
    expect(jobs, hasLength(1));

    await expectLater(printJob('127.0.0.1', silent.port, 'auto', build), throwsA(isA<PrintError>()));
  });

  Widget host(Widget child, Size size) => MaterialApp(
        theme: K.theme(),
        home: Scaffold(body: Center(child: SizedBox(width: size.width, height: size.height, child: child))),
      );

  testWidgets('the large view shows the printout, details and Print, and a tap shrinks it', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0, prints = 0, done = 0;
    await tester.pumpWidget(host(
      TicketCard(
        ticket: sampleTicket(),
        fs: 25,
        minutes: 3,
        tone: Tone.ok,
        showRaw: false,
        fillHeight: true,
        expanded: true,
        onTap: () => taps++,
        onPrint: () => prints++,
        onDone: () => done++,
        onToggleRaw: () {},
      ),
      const Size(1200, 900),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Original bon'), findsOneWidget);
    expect(find.text('192.168.1.20'), findsOneWidget);
    expect(find.text('Tryk på bonnen igen for at gøre den lille'), findsOneWidget);

    await tester.tap(find.text('Print'));
    await tester.tap(find.text('Færdig'));
    expect((prints, done, taps), (1, 1, 0), reason: 'buttons do their own thing, not shrink');

    await tester.tap(find.text('Wienerschnitzel').first);
    expect(taps, 1);
  });

  testWidgets('a small ticket opens on tap and has no Print button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      TicketCard(
        ticket: sampleTicket(),
        fs: 20,
        minutes: 3,
        tone: Tone.ok,
        showRaw: false,
        fillHeight: true,
        onTap: () => taps++,
        onPrint: () {},
        onDone: () {},
        onToggleRaw: () {},
      ),
      const Size(340, 700),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Print'), findsNothing);
    await tester.tap(find.text('Wienerschnitzel'));
    expect(taps, 1);
  });
}
