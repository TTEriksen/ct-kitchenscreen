'use strict';

const { decodeBytes, ESC_T } = require('./codepages');

const ESC = 0x1b;
const GS = 0x1d;
const FS = 0x1c;
const DLE = 0x10;
const LF = 0x0a;

/**
 * Turn the raw bytes of a print job into pages of styled text lines.
 * A page ends at every paper cut; a job without a cut is one page.
 *
 * @param {Buffer} buf
 * @param {{ protocol?: 'escpos'|'star', charset?: string }} opts
 * @returns {{ lines: Line[] }[]}
 *
 * @typedef {{ text: string, bold: boolean, big: boolean, red: boolean,
 *             inverse: boolean, underline: boolean, align: 'left'|'center'|'right' }} Line
 */
function decode(buf, opts = {}) {
  const star = opts.protocol === 'star';
  const charset = opts.charset || 'auto';

  const pages = [];
  let lines = [];
  let cur = [];
  const st = freshState();
  let lineAttr = blankAttr();

  function freshState() {
    return { bold: false, big: false, red: false, inverse: false, underline: false, align: 'left', page: 'cp865', intl: 0 };
  }
  function blankAttr() {
    return { bold: false, big: false, red: false, inverse: false, underline: false };
  }
  function reset() {
    Object.assign(st, freshState());
  }
  function pushChar(b) {
    cur.push(b);
    if (b !== 0x20) {
      if (st.bold) lineAttr.bold = true;
      if (st.big) lineAttr.big = true;
      if (st.red) lineAttr.red = true;
      if (st.inverse) lineAttr.inverse = true;
      if (st.underline) lineAttr.underline = true;
    }
  }
  function endLine() {
    const text = decodeBytes(cur, st.page, st.intl, charset).replace(/\s+$/, '');
    lines.push({ text, align: st.align, ...lineAttr });
    cur = [];
    lineAttr = blankAttr();
  }
  function endPage() {
    if (cur.length) endLine();
    if (lines.some((l) => l.text.trim())) pages.push({ lines: trimBlank(lines) });
    lines = [];
  }
  const at = (i) => (i < buf.length ? buf[i] : 0);
  const len16 = (i) => at(i) + at(i + 1) * 256;

  let i = 0;
  while (i < buf.length) {
    const b = buf[i];

    if (b === LF) { endLine(); i++; continue; }
    if (b === 0x0d) { i++; continue; }
    if (b === 0x09) { pushChar(0x20); pushChar(0x20); i++; continue; }
    if (b === 0x0c) { endLine(); i++; continue; }

    if (b === DLE) {
      const c = at(i + 1);
      if (c === 0x04 || c === 0x05) i += 3;
      else if (c === 0x14) i += 5;
      else i += 1;
      continue;
    }

    if (b === ESC) {
      const c = at(i + 1);
      if (star) { i = starEsc(i, c); continue; }
      switch (c) {
        case 0x40: reset(); i += 2; break; // @ init
        case 0x21: { // ! print mode
          const n = at(i + 2);
          st.bold = !!(n & 0x08);
          st.big = !!(n & 0x30);
          st.underline = !!(n & 0x80);
          i += 3; break;
        }
        case 0x45: case 0x47: st.bold = !!(at(i + 2) & 1); i += 3; break; // E / G bold
        case 0x2d: st.underline = !!(at(i + 2) & 3); i += 3; break; // - underline
        case 0x61: st.align = alignOf(at(i + 2)); i += 3; break; // a align
        case 0x72: st.red = !!(at(i + 2) & 1); i += 3; break; // r colour
        case 0x74: st.page = ESC_T[at(i + 2)] || st.page; i += 3; break; // t code page
        case 0x52: st.intl = at(i + 2); i += 3; break; // R intl set
        case 0x64: case 0x4a: endLine(); i += 3; break; // d / J feed
        case 0x69: case 0x6d: endPage(); i += 2; break; // i / m cut
        case 0x70: i += 5; break; // p drawer kick
        case 0x2a: { // * bit image
          const m = at(i + 2);
          const n = len16(i + 3);
          i += 5 + n * (m === 32 || m === 33 ? 3 : 1); break;
        }
        case 0x24: case 0x5c: pushChar(0x20); i += 4; break; // $ / \ positioning
        case 0x44: { // D tab stops, NUL-terminated
          let j = i + 2;
          while (j < buf.length && buf[j] !== 0) j++;
          i = j + 1; break;
        }
        case 0x63: i += 4; break; // c 3/4/5 n
        case 0x26: i = buf.length; break; // & user chars: give up on the rest
        case 0x32: case 0x3c: i += 2; break; // 2, <
        case 0x57: i += 10; break; // W print area
        case 0x28: i += 5 + len16(i + 3); break; // ESC ( fn pL pH …
        default: i += 3; // ESC x n: one-argument commands (SP 3 M U V { % e …)
      }
      continue;
    }

    if (b === GS) {
      const c = at(i + 1);
      switch (c) {
        case 0x21: { // ! size
          const n = at(i + 2);
          st.big = (n & 0x0f) > 0 || (n & 0xf0) > 0;
          i += 3; break;
        }
        case 0x42: st.inverse = !!(at(i + 2) & 1); i += 3; break; // B reverse
        case 0x56: { // V cut
          const m = at(i + 2);
          endPage();
          i += (m === 0 || m === 1 || m === 48 || m === 49) ? 3 : 4; break;
        }
        case 0x76: { // v 0 raster image
          const x = len16(i + 4);
          const y = len16(i + 6);
          i += 8 + x * y; break;
        }
        case 0x28: i += 5 + len16(i + 3); break; // ( fn pL pH data
        case 0x38: { // 8 L p1..p4 data
          const n = at(i + 3) + (at(i + 4) << 8) + (at(i + 5) << 16) + (at(i + 6) << 24);
          i += 7 + n; break;
        }
        case 0x6b: { // k barcode
          const m = at(i + 2);
          if (m <= 6) {
            let j = i + 3;
            while (j < buf.length && buf[j] !== 0) j++;
            i = j + 1;
          } else {
            i += 4 + at(i + 3);
          }
          break;
        }
        case 0x2a: i += 4 + at(i + 2) * at(i + 3) * 8; break; // * download image
        case 0x4c: case 0x57: case 0x50: case 0x24: case 0x5c: i += 4; break; // L W P $ \ (2 args)
        default: i += 3; // GS x n: one-argument commands (H f h w a b I r E / …)
      }
      continue;
    }

    if (b === FS) {
      const c = at(i + 1);
      if (c === 0x26 || c === 0x2e) i += 2;
      else if (c === 0x70) i += 4;
      else if (c === 0x53) i += 4;
      else i += 3;
      continue;
    }

    if (b < 0x20) { i++; continue; }

    pushChar(b);
    i++;
  }
  endPage();
  return pages;

  // Star Line Mode: the subset kitchen printers are actually sent.
  function starEsc(i0, c) {
    switch (c) {
      case 0x40: reset(); return i0 + 2;
      case 0x45: st.bold = true; return i0 + 2; // E bold on
      case 0x46: st.bold = false; return i0 + 2; // F bold off
      case 0x34: st.red = true; return i0 + 2; // 4 red
      case 0x35: st.red = false; return i0 + 2; // 5 black
      case 0x2d: st.underline = !!(at(i0 + 2) & 1); return i0 + 3;
      case 0x69: st.big = at(i0 + 2) > 0 || at(i0 + 3) > 0; return i0 + 4; // i n1 n2 size
      case 0x57: case 0x68: st.big = at(i0 + 2) > 0; return i0 + 3; // W / h
      case 0x0e: st.big = true; return i0 + 2; // SO expanded
      case 0x14: st.big = false; return i0 + 2; // DC4
      case 0x64: endPage(); return i0 + 3; // d n cut
      case 0x52: st.intl = at(i0 + 2); return i0 + 3;
      case 0x1d: { // ESC GS …
        const d = at(i0 + 2);
        if (d === 0x61) { st.align = alignOf(at(i0 + 3)); return i0 + 4; }
        if (d === 0x74) { st.page = ESC_T[at(i0 + 3)] || st.page; return i0 + 4; }
        return i0 + 4;
      }
      case 0x1e: return i0 + 4; // ESC RS …
      case 0x07: return i0 + 4; // buzzer
      case 0x61: endLine(); return i0 + 3; // a n feed
      default: return i0 + 3;
    }
  }
}

function alignOf(n) {
  if (n === 1 || n === 0x31) return 'center';
  if (n === 2 || n === 0x32) return 'right';
  return 'left';
}

function trimBlank(lines) {
  let a = 0;
  let b = lines.length;
  while (a < b && !lines[a].text.trim()) a++;
  while (b > a && !lines[b - 1].text.trim()) b--;
  return lines.slice(a, b);
}

/**
 * Answers to real-time status requests, so a till that asks the printer
 * whether it is ready gets "online, paper ok, no error".
 * @param {Buffer} chunk
 * @returns {Buffer|null}
 */
function realtimeReplies(chunk) {
  const out = [];
  for (let i = 0; i < chunk.length - 2; i++) {
    if (chunk[i] === DLE && chunk[i + 1] === 0x04) {
      const n = chunk[i + 2];
      out.push(n === 1 ? 0x16 : 0x12);
    } else if (chunk[i] === GS && chunk[i + 1] === 0x72) {
      out.push(0x00); // GS r: paper sensors ok
    } else if (chunk[i] === GS && chunk[i + 1] === 0x49) {
      out.push(0x20); // GS I: printer model id
    }
  }
  return out.length ? Buffer.from(out) : null;
}

module.exports = { decode, realtimeReplies };
