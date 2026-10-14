import 'dart:io';

import 'package:ct_kitchenscreen/src/kitchen.dart';
import 'package:ct_kitchenscreen/src/printer/samples.dart';
import 'package:ct_kitchenscreen/src/ui/kitchen_screen.dart';
import 'package:ct_kitchenscreen/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late Kitchen kitchen;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kds_test');
  });
  tearDown(() async {
    kitchen.dispose();
    await dir.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    kitchen = (await tester.runAsync(() => Kitchen.open(dir: dir, listen: false)))!;
    kitchen.ingest(samples[0]()); // Bord 12
    kitchen.ingest(samples[1]()); // Bord 21
    kitchen.markDone(kitchen.active.first);
    await tester.pumpWidget(MaterialApp(theme: K.theme(), home: KitchenScreen(kitchen: kitchen)));
    await tester.pump();
  }

  testWidgets('the Afsluttede panel stays open, also when the opening touch lands on the background', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Afsluttede'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Afsluttede bonner'), findsOneWidget);

    // The same touch arriving at the dimmed background right away must not close it.
    await tester.tapAt(const Offset(100, 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Afsluttede bonner'), findsOneWidget);

    // Still open a while later, slid fully in, with the finished ticket and its button.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(find.text('Afsluttede bonner')).dx, lessThan(1366 - 400));
    expect(find.text('Afsluttede bonner'), findsOneWidget);
    expect(find.text('Hent tilbage'), findsOneWidget);

    // A deliberate tap beside it closes it, and so does ✕.
    await tester.tapAt(const Offset(100, 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Afsluttede bonner'), findsNothing);

    await tester.tap(find.text('Afsluttede'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // let it slide in
    await tester.tap(find.bySemanticsLabel('Luk'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Afsluttede bonner'), findsNothing);
  });

  testWidgets('Hent tilbage brings a finished ticket back while the panel stays open', (tester) async {
    await pumpScreen(tester);
    expect(kitchen.active, hasLength(1));
    await tester.tap(find.text('Afsluttede'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // let it slide in
    await tester.tap(find.text('Hent tilbage'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(kitchen.active, hasLength(2));
    expect(find.text('Afsluttede bonner'), findsOneWidget);
    expect(find.text('Ingen afsluttede bonner endnu.'), findsOneWidget);
  });

  testWidgets('a tapped ticket opens large and the opening touch does not shrink it', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Dagens suppe').first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Original bon'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // straight away: ignored
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Original bon'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Original bon'), findsNothing);
  });
}
