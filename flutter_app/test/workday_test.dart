import 'dart:io';

import 'package:ct_kitchenscreen/src/kitchen.dart';
import 'package:ct_kitchenscreen/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

Ticket ticket(String id, DateTime received, [DateTime? done]) => Ticket(
      id: id,
      seq: 1,
      receivedAt: received,
      doneAt: done,
      from: 'test',
      lines: [PrintLine(text: id)],
      parsed: ParsedTicket(),
    );

void main() {
  test('the workday starts at the set time, yesterday if that is still ahead', () {
    expect(workdayStart(DateTime(2026, 10, 14, 7, 30), '06:00'), DateTime(2026, 10, 14, 6));
    expect(workdayStart(DateTime(2026, 10, 14, 5, 59), '06:00'), DateTime(2026, 10, 13, 6));
    expect(workdayStart(DateTime(2026, 10, 1, 3), '06:00'), DateTime(2026, 9, 30, 6), reason: 'across a month');
  });

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('kds_day'));
  tearDown(() async => dir.delete(recursive: true));

  test('at 06:00 yesterday is cleared: Afsluttede starts at 0 and stale waiting tickets go', () async {
    final k = await Kitchen.open(dir: dir, listen: false);
    k.settings = Settings();
    for (final t in [
      ticket('done-yesterday', DateTime(2026, 10, 13, 21), DateTime(2026, 10, 13, 21, 20)),
      ticket('done-after-midnight', DateTime(2026, 10, 14, 1), DateTime(2026, 10, 14, 1, 30)),
      ticket('waiting-from-yesterday', DateTime(2026, 10, 13, 22, 40)),
      ticket('done-today', DateTime(2026, 10, 14, 6, 30), DateTime(2026, 10, 14, 6, 45)),
      ticket('waiting-today', DateTime(2026, 10, 14, 6, 50)),
    ]) {
      k.addForTest(t);
    }
    k.purgeAt(DateTime(2026, 10, 14, 5));
    expect(k.done.length + k.active.length, 5, reason: 'nothing goes before 06:00');
    k.purgeAt(DateTime(2026, 10, 14, 7));
    expect(k.done.map((t) => t.id), ['done-today']);
    expect(k.active.map((t) => t.id), ['waiting-today']);
    k.dispose();
  });

  test('waiting tickets can be kept, and hours still clear finished ones sooner', () async {
    final k = await Kitchen.open(dir: dir, listen: false);
    k.settings = Settings(keepDoneHours: 2, dayResetActive: false);
    k.addForTest(ticket('waiting-from-yesterday', DateTime(2026, 10, 13, 22, 40)));
    k.addForTest(ticket('done-3h-ago', DateTime(2026, 10, 14, 8), DateTime(2026, 10, 14, 9)));
    k.addForTest(ticket('done-1h-ago', DateTime(2026, 10, 14, 10, 30), DateTime(2026, 10, 14, 11)));
    k.purgeAt(DateTime(2026, 10, 14, 12));
    expect(k.active.map((t) => t.id), ['waiting-from-yesterday']);
    expect(k.done.map((t) => t.id), ['done-1h-ago']);
    k.dispose();
  });
}
