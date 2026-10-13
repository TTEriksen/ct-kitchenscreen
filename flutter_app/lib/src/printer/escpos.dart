import 'dart:typed_data';

import '../models.dart';
import 'codepages.dart';

const _esc = 0x1b;
const _gs = 0x1d;
const _fs = 0x1c;
const _dle = 0x10;
const _lf = 0x0a;

/// Turn the raw bytes of a print job into pages of styled text lines.
/// A page ends at every paper cut; a job without a cut is one page.
List<List<PrintLine>> decodeJob(List<int> buf, {String protocol = 'escpos', String charset = 'auto'}) {
  return _Decoder(buf, star: protocol == 'star', charset: charset).run();
}

class _Decoder {
  _Decoder(this.buf, {required this.star, required this.charset});

  final List<int> buf;
  final bool star;
  final String charset;

  final pages = <List<PrintLine>>[];
  var lines = <PrintLine>[];
  var cur = <int>[];

  // Current print state.
  var bold = false, big = false, red = false, inverse = false, underline = false;
  var align = 'left';
  var page = 'cp865';
  var intl = 0;

  // Attributes seen on the line being built.
  var lBold = false, lBig = false, lRed = false, lInverse = false, lUnderline = false;

  int at(int i) => i < buf.length ? buf[i] : 0;
  int len16(int i) => at(i) + at(i + 1) * 256;

  void reset() {
    bold = big = red = inverse = underline = false;
    align = 'left';
    page = 'cp865';
    intl = 0;
  }

  void pushChar(int b) {
    cur.add(b);
    if (b != 0x20) {
      lBold |= bold;
      lBig |= big;
      lRed |= red;
      lInverse |= inverse;
      lUnderline |= underline;
    }
  }

  void endLine() {
    final text = decodeBytes(cur, page, intl, charset).replaceFirst(RegExp(r'\s+$'), '');
    lines.add(PrintLine(text: text, bold: lBold, big: lBig, red: lRed, inverse: lInverse, underline: lUnderline, align: align));
    cur = [];
    lBold = lBig = lRed = lInverse = lUnderline = false;
  }

  void endPage() {
    if (cur.isNotEmpty) endLine();
    if (lines.any((l) => l.text.trim().isNotEmpty)) pages.add(_trimBlank(lines));
    lines = [];
  }

  List<List<PrintLine>> run() {
    var i = 0;
    while (i < buf.length) {
      final b = buf[i];
      if (b == _lf) {
        endLine();
        i++;
      } else if (b == 0x0d) {
        i++;
      } else if (b == 0x09) {
        pushChar(0x20);
        pushChar(0x20);
        i++;
      } else if (b == 0x0c) {
        endLine();
        i++;
      } else if (b == _dle) {
        final c = at(i + 1);
        i += (c == 0x04 || c == 0x05) ? 3 : (c == 0x14 ? 5 : 1);
      } else if (b == _esc) {
        i = star ? _starEsc(i) : _escCmd(i);
      } else if (b == _gs) {
        i = _gsCmd(i);
      } else if (b == _fs) {
        final c = at(i + 1);
        i += (c == 0x26 || c == 0x2e) ? 2 : ((c == 0x70 || c == 0x53) ? 4 : 3);
      } else if (b < 0x20) {
        i++;
      } else {
        pushChar(b);
        i++;
      }
    }
    endPage();
    return pages;
  }

  int _escCmd(int i) {
    final c = at(i + 1);
    switch (c) {
      case 0x40: // @ init
        reset();
        return i + 2;
      case 0x21: // ! print mode
        final n = at(i + 2);
        bold = n & 0x08 != 0;
        big = n & 0x30 != 0;
        underline = n & 0x80 != 0;
        return i + 3;
      case 0x45: // E bold
      case 0x47: // G double strike
        bold = at(i + 2) & 1 != 0;
        return i + 3;
      case 0x2d: // - underline
        underline = at(i + 2) & 3 != 0;
        return i + 3;
      case 0x61: // a align
        align = _alignOf(at(i + 2));
        return i + 3;
      case 0x72: // r colour
        red = at(i + 2) & 1 != 0;
        return i + 3;
      case 0x74: // t code page
        page = escT[at(i + 2)] ?? page;
        return i + 3;
      case 0x52: // R intl set
        intl = at(i + 2);
        return i + 3;
      case 0x64: // d feed
      case 0x4a: // J feed
        endLine();
        return i + 3;
      case 0x69: // i cut
      case 0x6d: // m cut
        endPage();
        return i + 2;
      case 0x70: // p drawer kick
        return i + 5;
      case 0x2a: // * bit image
        final m = at(i + 2);
        return i + 5 + len16(i + 3) * ((m == 32 || m == 33) ? 3 : 1);
      case 0x24: // $ absolute position
      case 0x5c: // \ relative position
        pushChar(0x20);
        return i + 4;
      case 0x44: // D tab stops, NUL-terminated
        var j = i + 2;
        while (j < buf.length && buf[j] != 0) {
          j++;
        }
        return j + 1;
      case 0x63: // c 3/4/5 n
        return i + 4;
      case 0x26: // & user-defined chars: give up on the rest
        return buf.length;
      case 0x32: // 2
      case 0x3c: // <
        return i + 2;
      case 0x57: // W print area
        return i + 10;
      case 0x28: // ESC ( fn pL pH …
        return i + 5 + len16(i + 3);
      default: // one-argument commands (SP 3 M U V { % e …)
        return i + 3;
    }
  }

  int _gsCmd(int i) {
    final c = at(i + 1);
    switch (c) {
      case 0x21: // ! size
        big = at(i + 2) != 0;
        return i + 3;
      case 0x42: // B reverse
        inverse = at(i + 2) & 1 != 0;
        return i + 3;
      case 0x56: // V cut
        final m = at(i + 2);
        endPage();
        return i + ((m == 0 || m == 1 || m == 48 || m == 49) ? 3 : 4);
      case 0x76: // v 0 raster image
        return i + 8 + len16(i + 4) * len16(i + 6);
      case 0x28: // ( fn pL pH data
        return i + 5 + len16(i + 3);
      case 0x38: // 8 L p1..p4 data
        final n = at(i + 3) + (at(i + 4) << 8) + (at(i + 5) << 16) + (at(i + 6) << 24);
        return i + 7 + n;
      case 0x6b: // k barcode
        final m = at(i + 2);
        if (m <= 6) {
          var j = i + 3;
          while (j < buf.length && buf[j] != 0) {
            j++;
          }
          return j + 1;
        }
        return i + 4 + at(i + 3);
      case 0x2a: // * download image
        return i + 4 + at(i + 2) * at(i + 3) * 8;
      case 0x4c: // L
      case 0x57: // W
      case 0x50: // P
      case 0x24: // $
      case 0x5c: // \
        return i + 4;
      default: // one-argument commands (H f h w a b I r E / …)
        return i + 3;
    }
  }

  // Star Line Mode: the subset kitchen printers are actually sent.
  int _starEsc(int i) {
    final c = at(i + 1);
    switch (c) {
      case 0x40:
        reset();
        return i + 2;
      case 0x45: // E bold on
        bold = true;
        return i + 2;
      case 0x46: // F bold off
        bold = false;
        return i + 2;
      case 0x34: // 4 red
        red = true;
        return i + 2;
      case 0x35: // 5 black
        red = false;
        return i + 2;
      case 0x2d:
        underline = at(i + 2) & 1 != 0;
        return i + 3;
      case 0x69: // i n1 n2 size
        big = at(i + 2) > 0 || at(i + 3) > 0;
        return i + 4;
      case 0x57: // W
      case 0x68: // h
        big = at(i + 2) > 0;
        return i + 3;
      case 0x0e: // SO expanded
        big = true;
        return i + 2;
      case 0x14: // DC4
        big = false;
        return i + 2;
      case 0x64: // d n cut
        endPage();
        return i + 3;
      case 0x52:
        intl = at(i + 2);
        return i + 3;
      case 0x1d: // ESC GS …
        final d = at(i + 2);
        if (d == 0x61) align = _alignOf(at(i + 3));
        if (d == 0x74) page = escT[at(i + 3)] ?? page;
        return i + 4;
      case 0x1e: // ESC RS …
      case 0x07: // buzzer
        return i + 4;
      case 0x61: // a n feed
        endLine();
        return i + 3;
      default:
        return i + 3;
    }
  }
}

String _alignOf(int n) {
  if (n == 1 || n == 0x31) return 'center';
  if (n == 2 || n == 0x32) return 'right';
  return 'left';
}

List<PrintLine> _trimBlank(List<PrintLine> lines) {
  var a = 0;
  var b = lines.length;
  while (a < b && lines[a].text.trim().isEmpty) {
    a++;
  }
  while (b > a && lines[b - 1].text.trim().isEmpty) {
    b--;
  }
  return lines.sublist(a, b);
}

/// Answers to real-time status requests, so a till that asks the printer
/// whether it is ready gets "online, paper ok, no error".
Uint8List? realtimeReplies(List<int> chunk) {
  final out = <int>[];
  for (var i = 0; i < chunk.length - 2; i++) {
    if (chunk[i] == _dle && chunk[i + 1] == 0x04) {
      out.add(chunk[i + 2] == 1 ? 0x16 : 0x12);
    } else if (chunk[i] == _gs && chunk[i + 1] == 0x72) {
      out.add(0x00); // GS r: paper sensors ok
    } else if (chunk[i] == _gs && chunk[i + 1] == 0x49) {
      out.add(0x20); // GS I: printer model id
    }
  }
  return out.isEmpty ? null : Uint8List.fromList(out);
}
