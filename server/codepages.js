'use strict';

// Upper halves (0x80–0xFF) of the code pages kitchen printers are usually driven with.
// The lower half is ASCII, except where an ESC R international set swaps a few characters.

const CP437_HIGH =
  'ÇüéâäàåçêëèïîìÄÅ' +
  'ÉæÆôöòûùÿÖÜ¢£¥₧ƒ' +
  'áíóúñÑªº¿⌐¬½¼¡«»' +
  '░▒▓│┤╡╢╖╕╣║╗╝╜╛┐' +
  '└┴┬├─┼╞╟╚╔╩╦╠═╬╧' +
  '╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀' +
  'αßΓπΣσµτΦΘΩδ∞φε∩' +
  '≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ';

// PC865 (Nordic) is PC437 with ø, Ø and ¤ in place of ¢, ¥ and ».
const CP865_HIGH = CP437_HIGH.split('');
CP865_HIGH[0x9b - 0x80] = 'ø';
CP865_HIGH[0x9d - 0x80] = 'Ø';
CP865_HIGH[0xaf - 0x80] = '¤';

const CP850_HIGH =
  'ÇüéâäàåçêëèïîìÄÅ' +
  'ÉæÆôöòûùÿÖÜø£Ø×ƒ' +
  'áíóúñÑªº¿®¬½¼¡«»' +
  '░▒▓│┤ÁÂÀ©╣║╗╝¢¥┐' +
  '└┴┬├─┼ãÃ╚╔╩╦╠═╬¤' +
  'ðÐÊËÈıÍÎÏ┘┌█▄¦Ì▀' +
  'ÓßÔÒõÕµþÞÚÛÙýÝ¯´' +
  '­±‗¾¶§÷¸°¨·¹³²■ ';

// PC858 is PC850 with € at 0xD5.
const CP858_HIGH = CP850_HIGH.split('');
CP858_HIGH[0xd5 - 0x80] = '€';

const CP1252_8X =
  '€\u0081‚ƒ„…†‡ˆ‰Š‹Œ\u008dŽ\u008f' +
  '\u0090‘’“”•–—˜™š›œ\u009džŸ';

function cp1252Char(b) {
  if (b >= 0x80 && b < 0xa0) return CP1252_8X[b - 0x80];
  return String.fromCharCode(b); // 0xA0–0xFF match Latin-1
}

const TABLES = {
  cp437: CP437_HIGH.split(''),
  cp865: CP865_HIGH,
  cp850: CP850_HIGH.split(''),
  cp858: CP858_HIGH,
};

// ESC t n → code page name.
const ESC_T = { 0: 'cp437', 2: 'cp850', 5: 'cp865', 16: 'cp1252', 19: 'cp858' };

// ESC R n → international character set: replacements in the ASCII range.
const INTL = {
  2: { 0x40: '§', 0x5b: 'Ä', 0x5c: 'Ö', 0x5d: 'Ü', 0x7b: 'ä', 0x7c: 'ö', 0x7d: 'ü', 0x7e: 'ß' }, // Germany
  4: { 0x5b: 'Æ', 0x5c: 'Ø', 0x5d: 'Å', 0x7b: 'æ', 0x7c: 'ø', 0x7d: 'å' }, // Denmark I
  5: { 0x24: '¤', 0x40: 'É', 0x5b: 'Ä', 0x5c: 'Ö', 0x5d: 'Å', 0x5e: 'Ü', 0x60: 'é', 0x7b: 'ä', 0x7c: 'ö', 0x7d: 'å', 0x7e: 'ü' }, // Sweden
  9: { 0x24: '¤', 0x40: 'É', 0x5b: 'Æ', 0x5c: 'Ø', 0x5d: 'Å', 0x5e: 'Ü', 0x60: 'é', 0x7b: 'æ', 0x7c: 'ø', 0x7d: 'å', 0x7e: 'ü' }, // Norway
  10: { 0x24: '¤', 0x40: 'É', 0x5b: 'Æ', 0x5c: 'Ø', 0x5d: 'Å', 0x5e: 'Ü', 0x60: 'é', 0x7b: 'æ', 0x7c: 'ø', 0x7d: 'å', 0x7e: 'ü' }, // Denmark II
};

function isUtf8Multibyte(bytes) {
  let multi = false;
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i];
    if (b < 0x80) continue;
    let n;
    if ((b & 0xe0) === 0xc0) n = 1;
    else if ((b & 0xf0) === 0xe0) n = 2;
    else if ((b & 0xf8) === 0xf0) n = 3;
    else return false;
    for (let k = 1; k <= n; k++) {
      if ((bytes[i + k] & 0xc0) !== 0x80) return false;
    }
    if (b === 0xc0 || b === 0xc1) return false;
    i += n;
    multi = true;
  }
  return multi;
}

/**
 * Decode one line of printed bytes.
 * @param {number[]} bytes
 * @param {string} page   code page chosen by ESC t (or the default)
 * @param {number} intl   ESC R set
 * @param {string} mode   'auto' | 'utf8' | 'cp865' | 'cp850' | 'cp858' | 'cp437' | 'cp1252'
 */
function decodeBytes(bytes, page, intl, mode) {
  if (mode === 'utf8' || (mode === 'auto' && isUtf8Multibyte(bytes))) {
    return Buffer.from(bytes).toString('utf8');
  }
  const cp = mode === 'auto' ? page : mode;
  const table = TABLES[cp];
  const swaps = INTL[intl] || null;
  let out = '';
  for (const b of bytes) {
    if (b < 0x80) out += swaps && swaps[b] ? swaps[b] : String.fromCharCode(b);
    else if (cp === 'cp1252') out += cp1252Char(b);
    else out += (table || TABLES.cp865)[b - 0x80];
  }
  return out;
}

module.exports = { decodeBytes, ESC_T, isUtf8Multibyte };
