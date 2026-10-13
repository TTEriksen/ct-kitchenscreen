import 'dart:convert';

// Upper halves (0x80–0xFF) of the code pages kitchen printers are usually driven with.
// The lower half is ASCII, except where an ESC R international set swaps a few characters.

const String _cp437High = 'ÇüéâäàåçêëèïîìÄÅ'
    'ÉæÆôöòûùÿÖÜ¢£¥₧ƒ'
    'áíóúñÑªº¿⌐¬½¼¡«»'
    '░▒▓│┤╡╢╖╕╣║╗╝╜╛┐'
    '└┴┬├─┼╞╟╚╔╩╦╠═╬╧'
    '╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀'
    'αßΓπΣσµτΦΘΩδ∞φε∩'
    '≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ';

const String _cp850High = 'ÇüéâäàåçêëèïîìÄÅ'
    'ÉæÆôöòûùÿÖÜø£Ø×ƒ'
    'áíóúñÑªº¿®¬½¼¡«»'
    '░▒▓│┤ÁÂÀ©╣║╗╝¢¥┐'
    '└┴┬├─┼ãÃ╚╔╩╦╠═╬¤'
    'ðÐÊËÈıÍÎÏ┘┌█▄¦Ì▀'
    'ÓßÔÒõÕµþÞÚÛÙýÝ¯´'
    '­±‗¾¶§÷¸°¨·¹³²■ ';

const String _cp1252x8 = '€\u0081‚ƒ„…†‡ˆ‰Š‹Œ\u008dŽ\u008f'
    '\u0090‘’“”•–—˜™š›œ\u009džŸ';

List<String> _chars(String s) => s.runes.map(String.fromCharCode).toList();

final Map<String, List<String>> _tables = () {
  final cp437 = _chars(_cp437High);
  // PC865 (Nordic) is PC437 with ø, Ø and ¤ in place of ¢, ¥ and ».
  final cp865 = List<String>.of(cp437)
    ..[0x9b - 0x80] = 'ø'
    ..[0x9d - 0x80] = 'Ø'
    ..[0xaf - 0x80] = '¤';
  final cp850 = _chars(_cp850High);
  // PC858 is PC850 with € at 0xD5.
  final cp858 = List<String>.of(cp850)..[0xd5 - 0x80] = '€';
  return {'cp437': cp437, 'cp865': cp865, 'cp850': cp850, 'cp858': cp858};
}();

/// ESC t n → code page name.
const Map<int, String> escT = {0: 'cp437', 2: 'cp850', 5: 'cp865', 16: 'cp1252', 19: 'cp858'};

/// ESC R n → international character set: replacements in the ASCII range.
const Map<int, Map<int, String>> _intl = {
  2: {0x40: '§', 0x5b: 'Ä', 0x5c: 'Ö', 0x5d: 'Ü', 0x7b: 'ä', 0x7c: 'ö', 0x7d: 'ü', 0x7e: 'ß'},
  4: {0x5b: 'Æ', 0x5c: 'Ø', 0x5d: 'Å', 0x7b: 'æ', 0x7c: 'ø', 0x7d: 'å'},
  5: {0x24: '¤', 0x40: 'É', 0x5b: 'Ä', 0x5c: 'Ö', 0x5d: 'Å', 0x5e: 'Ü', 0x60: 'é', 0x7b: 'ä', 0x7c: 'ö', 0x7d: 'å', 0x7e: 'ü'},
  9: {0x24: '¤', 0x40: 'É', 0x5b: 'Æ', 0x5c: 'Ø', 0x5d: 'Å', 0x5e: 'Ü', 0x60: 'é', 0x7b: 'æ', 0x7c: 'ø', 0x7d: 'å', 0x7e: 'ü'},
  10: {0x24: '¤', 0x40: 'É', 0x5b: 'Æ', 0x5c: 'Ø', 0x5d: 'Å', 0x5e: 'Ü', 0x60: 'é', 0x7b: 'æ', 0x7c: 'ø', 0x7d: 'å', 0x7e: 'ü'},
};

bool isUtf8Multibyte(List<int> bytes) {
  var multi = false;
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (b < 0x80) continue;
    int n;
    if ((b & 0xe0) == 0xc0) {
      n = 1;
    } else if ((b & 0xf0) == 0xe0) {
      n = 2;
    } else if ((b & 0xf8) == 0xf0) {
      n = 3;
    } else {
      return false;
    }
    if (b == 0xc0 || b == 0xc1) return false;
    for (var k = 1; k <= n; k++) {
      if (i + k >= bytes.length || (bytes[i + k] & 0xc0) != 0x80) return false;
    }
    i += n;
    multi = true;
  }
  return multi;
}

/// Decode one line of printed bytes.
/// [mode] is 'auto', 'utf8', 'cp865', 'cp850', 'cp858', 'cp437' or 'cp1252'.
String decodeBytes(List<int> bytes, String page, int intl, String mode) {
  if (mode == 'utf8' || (mode == 'auto' && isUtf8Multibyte(bytes))) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  final cp = mode == 'auto' ? page : mode;
  final table = _tables[cp] ?? _tables['cp865']!;
  final swaps = _intl[intl];
  final out = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80) {
      out.write(swaps?[b] ?? String.fromCharCode(b));
    } else if (cp == 'cp1252') {
      out.write(b < 0xa0 ? _cp1252x8[b - 0x80] : String.fromCharCode(b));
    } else {
      out.write(table[b - 0x80]);
    }
  }
  return out.toString();
}
