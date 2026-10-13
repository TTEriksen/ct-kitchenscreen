// Reads the text of one printed kitchen ticket and pulls out what the kitchen needs:
// table, guests, ticket number, waiter, time, courses with items and modifiers,
// allergens and notes. Tills format tickets differently, so this is deliberately
// forgiving: anything it cannot place is kept as an extra line, and the original
// printout is always stored next to the result.

import '../models.dart';

const _courseWords = {
  'forret', 'forretter', 'hovedret', 'hovedretter', 'mellemret', 'mellemretter', 'dessert', 'desserter',
  'børnemenu', 'børneret', 'tilbehør', 'snacks', 'frokost', 'aften', 'brunch', 'menu',
  'starter', 'starters', 'appetizer', 'appetizers', 'main', 'mains', 'main course', 'sides', 'kids',
  'take away', 'takeaway', 'ud af huset', 'to go',
};

RegExp _rx(String s) => RegExp(s, caseSensitive: false);

final _table = _rx(r'\b(?:bord|table|tbl|tisch)\b\s*(?:nr\.?|no\.?)?\s*[:#.\-]?\s*([A-Za-zÆØÅæøå]?\d+[A-Za-z]?)');
final _guests = [
  _rx(r'\b(\d{1,3})\s*(?:pers\.?|personer|person|gæster|gæst|guests?|covers?|cov|pax|kuverter)(?![A-Za-zæøå])'),
  _rx(r'\b(?:pers\.?|personer|gæster|guests?|covers?|cov|pax|kuverter)\s*[:.\-]?\s*(\d{1,3})\b'),
];
final _order = _rx(r'\b(?:bon|ordre|order|ticket|kvittering|bestilling|nr|no)\b\.?\s*(?:nr\.?|no\.?)?\s*[:#.\-]?\s*#?\s*(\d{1,8})\b');
final _hashOrder = RegExp(r'^#\s*(\d{1,8})\b');
final _waiter = _rx(r'\b(?:tjener|waiter|server|servitør|ekspedient|medarbejder|staff|bruger|user|operatør|kasserer)\s*[:.\-]?\s*([^\d:].*?)\s*$');
final _time = RegExp(r'\b([01]?\d|2[0-3])[:.]([0-5]\d)(?:[:.][0-5]\d)?\b');
final _date = RegExp(r'\b\d{1,4}[-./]\d{1,2}[-./]\d{1,4}\b');
final _takeaway = _rx(r'\b(take\s?away|ud af huset|afhentning|afhentes|to go|levering|delivery|wolt|just eat|foodora)\b');
final _note = _rx(r'^\s*(?:note|notat|noter|bem\.?|bemærkning|bemærk|kommentar|comment|comments|info|obs|besked|message|msg|kokken|til køkken)\s*[:.!\-]\s*(.*)$');
final _starNote = RegExp(r'^\s*[*!>]{2,}\s*(.+?)\s*[*!<]*\s*$');
final _item = _rx(r'^\s*(\d{1,3})\s*(?:x|×|stk\.?|pcs\.?|\*)?\s+(\S.*)$');
final _itemSuffixQty = _rx(r'^\s*(\S.*?)\s+(?:x|×)\s*(\d{1,3})\s*$');
final _modPrefix = _rx(r'^\s*(?:[-+*>•~=]+|\(|uden\b|med\b|ekstra\b|ingen\b|ikke\b|kun\b|no\b|extra\b|without\b|with\b|add\b|sub\b|bytte?\b|i stedet\b|well done\b|medium\b|rare\b|rød\b|rosa\b|gennemstegt\b)');
final _price = _rx(r'\s+-?\d{1,6}(?:[.,]\d{2})?\s*(?:kr\.?|dkk|,-)?\s*$');
final _priceOnly = _rx(r'^\s*-?\d{1,6}[.,]\d{2}\s*(?:kr\.?|dkk)?\s*$');
final _decor = RegExp(r'^[\s\-=_*~.#+]*$');
final _money = _rx(r'^\s*(?:total|i alt|ialt|subtotal|sum|moms|vat|tax|beløb|at betale|betalt|byttepenge|rabat|discount|kort|kontant)\b');
final _printHeader = _rx(r'^\s*(?:køkken|kitchen|bar|kold køkken|varm køkken|printer|kopi|copy|reprint|genprint|bestilling)\s*\d*\s*$');

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String? _isCourse(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'[\-=*:_#]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return _courseWords.contains(t) ? _cap(t) : null;
}

/// Matches at the start of a word, so "nød" also finds "nøddeallergi" and "gluten" finds "glutenfri".
bool hasAllergen(String text, List<String> words) {
  final t = text.toLowerCase();
  for (final w in words) {
    final re = RegExp('(^|[^a-zæøåäöüé])${RegExp.escape(w.toLowerCase())}');
    if (re.hasMatch(t)) return true;
  }
  return false;
}

String _stripPrice(String s) {
  if (RegExp(r'\d[.,]\d{2}\s*(kr\.?|dkk)?\s*$', caseSensitive: false).hasMatch(s) ||
      RegExp(r'\d\s*(kr\.?|dkk|,-)\s*$', caseSensitive: false).hasMatch(s)) {
    return s.replaceFirst(_price, '').trim();
  }
  return s.trim();
}

ParsedTicket parseTicket(List<PrintLine> lines, {List<String>? allergenWords}) {
  final words = (allergenWords == null || allergenWords.isEmpty) ? Settings.defaultAllergenWords : allergenWords;
  final out = ParsedTicket();

  Section? section;
  Item? lastItem;
  var lastItemIndent = 0;
  Section newSection(String? course) {
    final s = Section(course);
    out.sections.add(s);
    section = s;
    return s;
  }

  for (final line in lines) {
    final raw = line.text.replaceAll('\t', '  ');
    final text = raw.trim();
    if (text.isEmpty || _decor.hasMatch(text)) continue;
    final indent = raw.length - raw.trimLeft().length;
    final highlighted = line.red || line.inverse;
    var consumed = false;

    // Header facts. A line can carry several ("Bord 12   4 pers.   18:02").
    final tm = _table.firstMatch(text);
    if (tm != null && out.table == null) {
      out.table = tm.group(1);
      consumed = true;
    }
    for (final g in _guests) {
      final gm = g.firstMatch(text);
      if (gm != null && out.guests == null) {
        out.guests = int.parse(gm.group(1)!);
        consumed = true;
        break;
      }
    }
    final om = _order.firstMatch(text) ?? _hashOrder.firstMatch(text);
    if (om != null && out.orderNo == null && !(tm != null && om.group(1) == tm.group(1))) {
      out.orderNo = om.group(1);
      consumed = true;
    }
    final wm = _waiter.firstMatch(text);
    if (wm != null && out.waiter == null) {
      out.waiter = wm.group(1)!.replaceFirst(RegExp(r'\s{2,}.*'), '').trim();
      consumed = true;
    }
    final tim = _time.firstMatch(text);
    final timeOnly = tim != null &&
        text
            .replaceFirst(_time, '')
            .replaceFirst(_rx(r'\b(kl|tid|time)\b\.?'), '')
            .replaceAll(RegExp(r'[\s:.]'), '')
            .isEmpty;
    if (tim != null && (consumed || timeOnly || _date.hasMatch(text))) {
      out.time ??= '${tim.group(1)!.padLeft(2, '0')}:${tim.group(2)}';
      consumed = true;
    }
    if (_date.hasMatch(text) && !_item.hasMatch(text)) consumed = true;
    final tk = _takeaway.firstMatch(text);
    if (tk != null && out.takeaway == null) out.takeaway = _cap(tk.group(1)!.toLowerCase());
    if (consumed) continue;

    if (_money.hasMatch(text) || _priceOnly.hasMatch(text) || _printHeader.hasMatch(text)) continue;

    // Notes.
    final nm = _note.firstMatch(text);
    if (nm != null) {
      final body = nm.group(1)!.trim();
      if (body.isNotEmpty) {
        (hasAllergen(body, words) ? out.allergens : out.notes).add(body);
      }
      continue;
    }

    // Course headings.
    final course = _isCourse(text);
    if (course != null) {
      if (_rx(r'take\s?away|ud af huset|to go').hasMatch(course)) out.takeaway ??= course;
      newSection(course);
      lastItem = null;
      continue;
    }

    // "*** Selskab - server samlet ***" and similar shouted lines are notes, not modifiers.
    final shout = _starNote.firstMatch(text);
    if (shout != null && !_item.hasMatch(text)) {
      final body = shout.group(1)!.replaceFirst(RegExp(r'[*!<\s]+$'), '');
      (hasAllergen(body, words) ? out.allergens : out.notes).add(body);
      continue;
    }

    // Modifiers: indented, or starting with -, +, "uden", "ekstra" …, right after an item.
    final item = lastItem;
    if (item != null && (indent > lastItemIndent || (_modPrefix.hasMatch(text) && !_item.hasMatch(text)))) {
      final modText = _stripPrice(text.replaceFirst(RegExp(r'^[-+*>•~=]+\s*'), '').replaceFirstMapped(RegExp(r'^\((.*)\)$'), (m) => m.group(1)!));
      if (modText.isNotEmpty) {
        final allergic = highlighted || hasAllergen(modText, words);
        item.mods.add(Mod(modText, allergy: allergic));
        if (allergic) {
          item.allergy = true;
          out.allergens.add('${item.name}: $modText');
        }
      }
      continue;
    }

    // Items.
    int? qty;
    String? name;
    final im = _item.firstMatch(text);
    final im2 = im?.group(2);
    if (im != null && !_time.hasMatch(im2!.substring(0, im2.length < 5 ? im2.length : 5))) {
      qty = int.parse(im.group(1)!);
      name = im2;
    } else {
      final sm = _itemSuffixQty.firstMatch(text);
      if (sm != null) {
        qty = int.parse(sm.group(2)!);
        name = sm.group(1);
      }
    }
    if (qty != null && qty > 0 && name != null) {
      name = _stripPrice(name);
      final sec = section ?? newSection(null);
      final allergic = highlighted || hasAllergen(name, words);
      final it = Item(qty: qty, name: name, allergy: allergic);
      lastItem = it;
      lastItemIndent = indent;
      sec.items.add(it);
      if (allergic && !_rx('allerg').hasMatch(name)) out.allergens.add(name);
      continue;
    }

    // Free-standing allergen lines, highlighted lines and anything else.
    if (hasAllergen(text, words)) {
      out.allergens.add(text);
      continue;
    }
    final st = _starNote.firstMatch(text);
    if (st != null || highlighted) {
      out.notes.add(st != null ? st.group(1)! : text);
      continue;
    }
    out.extra.add(text);
  }

  out.sections = out.sections.where((s) => s.items.isNotEmpty).toList();
  out.allergens = out.allergens
      .map((a) => a.replaceAll(_rx(r'\ballergi(?:er)?\s*[:.\-]\s*'), '').trim())
      .where((a) => a.isNotEmpty)
      .toSet()
      .toList();

  if (out.sections.isEmpty) {
    // No dishes: a message from the floor. Show the whole printout so nothing is lost.
    out.isMessage = true;
    out.message = lines
        .map((l) => l.text.trim())
        .where((t) => t.isNotEmpty && !_decor.hasMatch(t) && !_rx(r'^(besked|message|info|til køkken)$').hasMatch(t))
        .join('\n');
    out.notes = [];
    out.extra = [];
  }
  return out;
}
