'use strict';

// Reads the text of one printed kitchen ticket and pulls out what the kitchen needs:
// table, guests, ticket number, waiter, time, courses with items and modifiers,
// allergens and notes. Tills format tickets differently, so this is deliberately
// forgiving: anything it cannot place is kept as an extra line, and the original
// printout is always stored next to the result.

const COURSE_WORDS = [
  'forret', 'forretter', 'hovedret', 'hovedretter', 'mellemret', 'mellemretter', 'dessert', 'desserter',
  'børnemenu', 'børneret', 'tilbehør', 'snacks', 'frokost', 'aften', 'brunch', 'menu',
  'starter', 'starters', 'appetizer', 'appetizers', 'main', 'mains', 'main course', 'sides', 'kids',
  'take away', 'takeaway', 'ud af huset', 'to go',
];

const DEFAULT_ALLERGEN_WORDS = [
  'allergi', 'allergy', 'allergen', 'allergiker', 'gluten', 'glutenfri', 'laktose', 'laktosefri', 'lactose',
  'mælkeprotein', 'mælk', 'nød', 'nødder', 'nødde', 'jordnød', 'jordnødder', 'peanut', 'peanuts', 'nut', 'nuts',
  'skaldyr', 'shellfish', 'krebsdyr', 'bløddyr', 'selleri', 'celery', 'sennep', 'mustard', 'sesam', 'sesame',
  'soja', 'soy', 'lupin', 'sulfit', 'svovl', 'cøliaki', 'fiskeallergi', 'ægallergi',
];

const RX = {
  table: /\b(?:bord|table|tbl|tisch)\b\s*(?:nr\.?|no\.?)?\s*[:#.\-]?\s*([A-Za-zÆØÅæøå]?\d+[A-Za-z]?)/i,
  guests: [
    /\b(\d{1,3})\s*(?:pers\.?|personer|person|gæster|gæst|guests?|covers?|cov|pax|kuverter)\b/i,
    /\b(?:pers\.?|personer|gæster|guests?|covers?|cov|pax|kuverter)\s*[:.\-]?\s*(\d{1,3})\b/i,
  ],
  order: /\b(?:bon|ordre|order|ticket|kvittering|bestilling|nr|no)\b\.?\s*(?:nr\.?|no\.?)?\s*[:#.\-]?\s*#?\s*(\d{1,8})\b/i,
  hashOrder: /^#\s*(\d{1,8})\b/,
  waiter: /\b(?:tjener|waiter|server|servitør|ekspedient|medarbejder|staff|bruger|user|operatør|kasserer)\s*[:.\-]?\s*([^\d:].*?)\s*$/i,
  time: /\b([01]?\d|2[0-3])[:.]([0-5]\d)(?:[:.][0-5]\d)?\b/,
  date: /\b\d{1,4}[-./]\d{1,2}[-./]\d{1,4}\b/,
  takeaway: /\b(take\s?away|ud af huset|afhentning|afhentes|to go|levering|delivery|wolt|just eat|foodora)\b/i,
  note: /^\s*(?:note|notat|noter|bem\.?|bemærkning|bemærk|kommentar|comment|comments|info|obs|besked|message|msg|kokken|til køkken)\s*[:.!\-]\s*(.*)$/i,
  starNote: /^\s*[*!>]{2,}\s*(.+?)\s*[*!<]*\s*$/,
  item: /^\s*(\d{1,3})\s*(?:x|×|stk\.?|pcs\.?|\*)?\s+(\S.*)$/i,
  itemSuffixQty: /^\s*(\S.*?)\s+(?:x|×)\s*(\d{1,3})\s*$/i,
  modPrefix: /^\s*(?:[-+*>•~=]+|\(|uden\b|med\b|ekstra\b|ingen\b|ikke\b|kun\b|no\b|extra\b|without\b|with\b|add\b|sub\b|bytte?\b|i stedet\b|well done\b|medium\b|rare\b|rød\b|rosa\b|gennemstegt\b)/i,
  price: /\s+-?\d{1,6}(?:[.,]\d{2})?\s*(?:kr\.?|dkk|,-)?\s*$/i,
  priceOnly: /^\s*-?\d{1,6}[.,]\d{2}\s*(?:kr\.?|dkk)?\s*$/i,
  decor: /^[\s\-=_*~.#+]*$/,
  money: /^\s*(?:total|i alt|ialt|subtotal|sum|moms|vat|tax|beløb|at betale|betalt|byttepenge|rabat|discount|kort|kontant)\b/i,
  printHeader: /^\s*(?:køkken|kitchen|bar|kold køkken|varm køkken|printer|kopi|copy|reprint|genprint|bestilling)\s*\d*\s*$/i,
};

function isCourse(s) {
  const t = s.toLowerCase().replace(/[\-=*:_#]+/g, ' ').replace(/\s+/g, ' ').trim();
  return COURSE_WORDS.includes(t) ? cap(t) : null;
}

function cap(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function hasAllergen(text, words) {
  const t = text.toLowerCase();
  return words.some((w) => {
    // Match at the start of a word, so "nød" also finds "nøddeallergi" and "gluten" finds "glutenfri".
    const re = new RegExp('(^|[^a-zæøåäöüé])' + escapeRx(w.toLowerCase()), 'i');
    return re.test(t);
  });
}

function escapeRx(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function stripPrice(s) {
  // Only strip a trailing number when something that looks like a price is there.
  if (/\d[.,]\d{2}\s*(kr\.?|dkk)?\s*$/i.test(s) || /\d\s*(kr\.?|dkk|,-)\s*$/i.test(s)) {
    return s.replace(RX.price, '').trim();
  }
  return s.trim();
}

/**
 * @param {{text:string,bold?:boolean,big?:boolean,red?:boolean,inverse?:boolean}[]} lines
 * @param {{ allergenWords?: string[] }} opts
 */
function parseTicket(lines, opts = {}) {
  const allergenWords = (opts.allergenWords && opts.allergenWords.length ? opts.allergenWords : DEFAULT_ALLERGEN_WORDS);
  const out = {
    table: null,
    guests: null,
    orderNo: null,
    waiter: null,
    time: null,
    takeaway: null,
    sections: [],
    allergens: [],
    notes: [],
    extra: [],
    isMessage: false,
    message: '',
  };

  let section = null;
  let lastItem = null;
  let lastItemIndent = 0;
  const newSection = (course) => {
    section = { course, items: [] };
    out.sections.push(section);
    return section;
  };

  for (const line of lines) {
    const raw = line.text.replace(/\t/g, '  ');
    const text = raw.trim();
    if (!text || RX.decor.test(text)) continue;
    const indent = raw.length - raw.trimStart().length;
    const highlighted = !!(line.red || line.inverse);
    let consumed = false;

    // Header facts. A line can carry several ("Bord 12   4 pers.   18:02").
    const tm = text.match(RX.table);
    if (tm && !out.table) { out.table = tm[1]; consumed = true; }
    for (const g of RX.guests) {
      const gm = text.match(g);
      if (gm && !out.guests) { out.guests = parseInt(gm[1], 10); consumed = true; break; }
    }
    const om = text.match(RX.order) || text.match(RX.hashOrder);
    if (om && !out.orderNo && !(tm && om[1] === tm[1])) { out.orderNo = om[1]; consumed = true; }
    const wm = text.match(RX.waiter);
    if (wm && !out.waiter) { out.waiter = wm[1].replace(/\s{2,}.*/, '').trim(); consumed = true; }
    const tim = text.match(RX.time);
    const timeOnly = tim && text.replace(RX.time, '').replace(/\b(kl|tid|time)\b\.?/i, '').replace(/[\s:.]/g, '').length === 0;
    if (tim && (consumed || timeOnly || RX.date.test(text))) {
      if (!out.time) out.time = tim[1].padStart(2, '0') + ':' + tim[2];
      consumed = true;
    }
    if (RX.date.test(text) && !RX.item.test(text)) consumed = true;
    const tk = text.match(RX.takeaway);
    if (tk && !out.takeaway) out.takeaway = cap(tk[1].toLowerCase());
    if (consumed) continue;

    if (RX.money.test(text) || RX.priceOnly.test(text) || RX.printHeader.test(text)) continue;

    // Notes.
    const nm = text.match(RX.note);
    if (nm) {
      const body = nm[1].trim();
      if (body) {
        if (hasAllergen(body, allergenWords)) out.allergens.push(body);
        else out.notes.push(body);
      }
      continue;
    }

    // Course headings.
    const course = isCourse(text);
    if (course) {
      if (/take\s?away|ud af huset|to go/i.test(course) && !out.takeaway) out.takeaway = course;
      newSection(course);
      lastItem = null;
      continue;
    }

    // "*** Selskab - server samlet ***" and similar shouted lines are notes, not modifiers.
    const shout = text.match(RX.starNote);
    if (shout && !RX.item.test(text)) {
      const body = shout[1].replace(/[*!<\s]+$/, '');
      if (hasAllergen(body, allergenWords)) out.allergens.push(body);
      else out.notes.push(body);
      continue;
    }

    // Modifiers: indented, or starting with -, +, "uden", "ekstra" …, right after an item.
    const isMod = lastItem && (indent > lastItemIndent || (RX.modPrefix.test(text) && !RX.item.test(text)));
    if (isMod) {
      const modText = stripPrice(text.replace(/^[-+*>•~=]+\s*/, '').replace(/^\((.*)\)$/, '$1'));
      if (modText) {
        const allergic = highlighted || hasAllergen(modText, allergenWords);
        lastItem.mods.push({ text: modText, allergy: allergic });
        if (allergic) {
          lastItem.allergy = true;
          out.allergens.push(lastItem.name + ': ' + modText);
        }
      }
      continue;
    }

    // Items.
    let im = text.match(RX.item);
    let qty;
    let name;
    if (im && !RX.time.test(im[2].slice(0, 5))) {
      qty = parseInt(im[1], 10);
      name = im[2];
    } else {
      im = text.match(RX.itemSuffixQty);
      if (im) { qty = parseInt(im[2], 10); name = im[1]; }
    }
    if (qty && name) {
      name = stripPrice(name);
      if (!section) newSection(null);
      const allergic = highlighted || hasAllergen(name, allergenWords);
      lastItem = { qty, name, mods: [], allergy: allergic };
      lastItemIndent = indent;
      section.items.push(lastItem);
      if (allergic && !/allerg/i.test(name)) out.allergens.push(name);
      continue;
    }

    // Free-standing allergen lines, highlighted lines and anything else.
    if (hasAllergen(text, allergenWords)) { out.allergens.push(text); continue; }
    const st = text.match(RX.starNote);
    if (st || highlighted) { out.notes.push(st ? st[1] : text); continue; }
    out.extra.push(text);
  }

  out.sections = out.sections.filter((s) => s.items.length);
  out.allergens = [...new Set(out.allergens.map((a) => a.replace(/\ballergi(?:er)?\s*[:.\-]\s*/ig, '').trim()).filter(Boolean))];

  if (!out.sections.length) {
    // No dishes: a message from the floor. Show the whole printout so nothing is lost.
    out.isMessage = true;
    out.message = lines
      .map((l) => l.text.trim())
      .filter((t) => t && !RX.decor.test(t) && !/^(besked|message|info|til køkken)$/i.test(t))
      .join('\n');
    out.notes = [];
    out.extra = [];
  }
  return out;
}

module.exports = { parseTicket, DEFAULT_ALLERGEN_WORDS };
