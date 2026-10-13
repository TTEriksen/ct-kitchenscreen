import 'dart:convert';

import 'package:ct_kitchenscreen/src/models.dart';
import 'package:ct_kitchenscreen/src/printer/escpos.dart';
import 'package:ct_kitchenscreen/src/printer/parser.dart';
import 'package:ct_kitchenscreen/src/printer/samples.dart';
import 'package:flutter_test/flutter_test.dart';

List<ParsedTicket> parse(List<int> bytes, {String protocol = 'escpos'}) =>
    decodeJob(bytes, protocol: protocol).map(parseTicket).toList();

void main() {
  test('decodes PC865 Danish letters and splits on cuts', () {
    final pages = decodeJob([...samples[0](), ...samples[3]()]);
    expect(pages.length, 2);
    expect(pages[0].any((l) => l.text == 'KØKKEN' && l.big && l.align == 'center'), isTrue);
    expect(pages[0].any((l) => l.text.contains('smørsauce')), isTrue);
  });

  test('reads table, guests, waiter, items, modifiers, allergens and notes', () {
    final t = parse(samples[0]()).single;
    expect(t.table, '12');
    expect(t.guests, 4);
    expect(t.waiter, 'Mette');
    expect(t.orderNo, isNotNull);
    expect(t.sections.single.course, 'Hovedret');
    final items = t.sections.single.items;
    expect(items.map((i) => '${i.qty} ${i.name}'), ['2 Wienerschnitzel', '1 Stjerneskud', '1 Børnefrikadeller']);
    expect(items[0].mods.map((m) => m.text), ['1 uden kapers', 'Ekstra smørsauce']);
    expect(items[1].allergy, isTrue);
    expect(t.allergens.first, contains('Gluten'));
    expect(t.notes, ['Børneretten først, gerne hurtigt']);
  });

  test('keeps several courses apart and turns shouted lines into notes', () {
    final t = parse(samples[1]()).single;
    expect(t.table, '21');
    expect(t.guests, 6);
    expect(t.sections.map((s) => s.course), ['Forret', 'Hovedret']);
    expect(t.allergens.any((a) => a.contains('nødde')), isTrue);
    expect(t.notes, ['SELSKAB - SERVER SAMLET']);
  });

  test('take away tickets without a table', () {
    final t = parse(samples[2]()).single;
    expect(t.table, isNull);
    expect(t.takeaway, 'Take away');
    expect(t.sections.single.items.length, 3);
  });

  test('a ticket without dishes is a message and keeps all its text', () {
    final t = parse(samples[3]()).single;
    expect(t.isMessage, isTrue);
    expect(t.message, contains('hold hovedretten 10 min'));
  });

  test('red printed modifiers count as allergens', () {
    final t = parse(samples[4]()).single;
    expect(t.sections.single.items[1].name, 'Vaniljeis');
    expect(t.sections.single.items[1].allergy, isTrue);
    expect(t.sections.single.items[0].name, 'Crème brûlée');
  });

  test('plain UTF-8 text jobs work too', () {
    final t = parse(utf8.encode('Bord 7\n2 pers.\n2 x Rød grød med fløde\n  ekstra fløde\nNote: hurtigt\n')).single;
    expect(t.table, '7');
    expect(t.sections.single.items.single.name, 'Rød grød med fløde');
    expect(t.sections.single.items.single.mods.map((m) => m.text), ['ekstra fløde']);
    expect(t.notes, ['hurtigt']);
  });

  test('prices and totals are left out', () {
    final t = parse(latin1.encode('Bord 3\n1 Burger           145,00\n2 Cola  50,00 kr\nTotal 245,00\n')).single;
    expect(t.sections.single.items.map((i) => i.name), ['Burger', 'Cola']);
    expect(t.extra, isEmpty);
  });

  test('skips raster images and barcodes without leaking bytes', () {
    final job = [
      0x1d, 0x76, 0x30, 0, 2, 0, 2, 0, 0x41, 0x42, 0x43, 0x44, // raster image
      0x1d, 0x28, 0x6b, 3, 0, 0x31, 0x50, 0x30, // QR data
      ...utf8.encode('Bord 4\n1 x Suppe\n'), 0x1d, 0x56, 0x00,
    ];
    final pages = decodeJob(job);
    expect(pages.length, 1);
    expect(pages[0][0].text, 'Bord 4');
  });

  test('Star Line mode bold, red and cut', () {
    final job = [
      0x1b, 0x40, 0x1b, 0x45, ...utf8.encode('Bord 8\n'), 0x1b, 0x46, ...utf8.encode('1 x Laks\n'),
      0x1b, 0x34, ...utf8.encode('  uden smør\n'), 0x1b, 0x35, 0x1b, 0x64, 0x02,
    ];
    final t = parse(job, protocol: 'star').single;
    expect(t.table, '8');
    expect(t.sections.single.items.single.allergy, isTrue);
  });

  test('status requests get an online answer', () {
    expect(realtimeReplies([0x10, 0x04, 0x01]), [0x16]);
    expect(realtimeReplies([0x10, 0x04, 0x04]), [0x12]);
  });

  test('tickets survive a save and load', () {
    final lines = decodeJob(samples[0]()).single;
    final t = Ticket(id: 'a', seq: 1, receivedAt: DateTime(2026, 10, 13, 18), from: 'x', lines: lines, parsed: parseTicket(lines));
    final back = Ticket.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(back.parsed.sections.single.items[1].allergy, isTrue);
    expect(back.lines.length, lines.length);
  });
}
