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
    expect(again.map((l) => l.text), page.map((l) => l.text));
    expect(again.firstWhere((l) => l.text.contains('ALLERGI')).red, isTrue);
    expect(again.firstWhere((l) => l.text == 'KØKKEN').big, isTrue);
  });

  test('a reprint starts with the copy heading', () {
    final again = decodeJob(ticketBytes(decodeJob(samples[2]()).single, copy: 'KOPI 18:42')).single;
    expect(again.first.text, 'KOPI 18:42');
    expect(again.first.inverse, isTrue);
  });

  test('sends to a network printer and reports one that is not there', () async {
    final received = <int>[];
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((s) => s.listen(received.addAll));
    await sendToPrinter('127.0.0.1', server.port, testPageBytes('Test'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final port = server.port;
    await server.close();
    expect(decodeJob(received).single.first.text, 'TESTUDSKRIFT');
    await expectLater(sendToPrinter('127.0.0.1', port, [1]), throwsA(isA<PrintError>()));
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
