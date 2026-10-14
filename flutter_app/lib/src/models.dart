// Data kept for each ticket and the screen's settings, with JSON for saving to disk.

class PrintLine {
  PrintLine({
    required this.text,
    this.bold = false,
    this.big = false,
    this.red = false,
    this.inverse = false,
    this.underline = false,
    this.align = 'left',
  });

  final String text;
  final bool bold;
  final bool big;
  final bool red;
  final bool inverse;
  final bool underline;
  final String align;

  Map<String, dynamic> toJson() => {
        'text': text,
        if (bold) 'bold': true,
        if (big) 'big': true,
        if (red) 'red': true,
        if (inverse) 'inverse': true,
        if (underline) 'underline': true,
        if (align != 'left') 'align': align,
      };

  factory PrintLine.fromJson(Map<String, dynamic> j) => PrintLine(
        text: j['text'] as String? ?? '',
        bold: j['bold'] == true,
        big: j['big'] == true,
        red: j['red'] == true,
        inverse: j['inverse'] == true,
        underline: j['underline'] == true,
        align: j['align'] as String? ?? 'left',
      );
}

class Mod {
  Mod(this.text, {this.allergy = false});
  final String text;
  final bool allergy;

  Map<String, dynamic> toJson() => {'text': text, if (allergy) 'allergy': true};
  factory Mod.fromJson(Map<String, dynamic> j) => Mod(j['text'] as String? ?? '', allergy: j['allergy'] == true);
}

class Item {
  Item({required this.qty, required this.name, List<Mod>? mods, this.allergy = false}) : mods = mods ?? [];
  final int qty;
  final String name;
  final List<Mod> mods;
  bool allergy;

  Map<String, dynamic> toJson() => {
        'qty': qty,
        'name': name,
        'mods': mods.map((m) => m.toJson()).toList(),
        if (allergy) 'allergy': true,
      };
  factory Item.fromJson(Map<String, dynamic> j) => Item(
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        name: j['name'] as String? ?? '',
        mods: ((j['mods'] as List?) ?? []).map((m) => Mod.fromJson(Map<String, dynamic>.from(m as Map))).toList(),
        allergy: j['allergy'] == true,
      );
}

class Section {
  Section(this.course, [List<Item>? items]) : items = items ?? [];
  final String? course;
  final List<Item> items;

  Map<String, dynamic> toJson() => {'course': course, 'items': items.map((i) => i.toJson()).toList()};
  factory Section.fromJson(Map<String, dynamic> j) => Section(
        j['course'] as String?,
        ((j['items'] as List?) ?? []).map((i) => Item.fromJson(Map<String, dynamic>.from(i as Map))).toList(),
      );
}

/// What the parser reads out of one printed ticket.
class ParsedTicket {
  String? table;
  int? guests;
  String? orderNo;
  String? waiter;
  String? time;
  String? takeaway;
  List<Section> sections = [];
  List<String> allergens = [];
  List<String> notes = [];
  List<String> extra = [];
  bool isMessage = false;
  String message = '';
}

class Ticket {
  Ticket({
    required this.id,
    required this.seq,
    required this.receivedAt,
    required this.from,
    required this.lines,
    required this.parsed,
    this.doneAt,
  });

  final String id;
  final int seq;
  final DateTime receivedAt;
  final String from;
  final List<PrintLine> lines;
  final ParsedTicket parsed;
  DateTime? doneAt;

  bool get isDone => doneAt != null;
  String get number => parsed.orderNo ?? '$seq';
  int get dishCount => parsed.sections.fold(0, (a, s) => a + s.items.fold(0, (b, i) => b + i.qty));

  Map<String, dynamic> toJson() => {
        'id': id,
        'seq': seq,
        'receivedAt': receivedAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
        'from': from,
        'lines': lines.map((l) => l.toJson()).toList(),
        'table': parsed.table,
        'guests': parsed.guests,
        'orderNo': parsed.orderNo,
        'waiter': parsed.waiter,
        'time': parsed.time,
        'takeaway': parsed.takeaway,
        'sections': parsed.sections.map((s) => s.toJson()).toList(),
        'allergens': parsed.allergens,
        'notes': parsed.notes,
        'extra': parsed.extra,
        'isMessage': parsed.isMessage,
        'message': parsed.message,
      };

  factory Ticket.fromJson(Map<String, dynamic> j) {
    List<String> strs(Object? v) => ((v as List?) ?? []).map((e) => '$e').toList();
    final p = ParsedTicket()
      ..table = j['table'] as String?
      ..guests = (j['guests'] as num?)?.toInt()
      ..orderNo = j['orderNo'] as String?
      ..waiter = j['waiter'] as String?
      ..time = j['time'] as String?
      ..takeaway = j['takeaway'] as String?
      ..sections = ((j['sections'] as List?) ?? []).map((s) => Section.fromJson(Map<String, dynamic>.from(s as Map))).toList()
      ..allergens = strs(j['allergens'])
      ..notes = strs(j['notes'])
      ..extra = strs(j['extra'])
      ..isMessage = j['isMessage'] == true
      ..message = j['message'] as String? ?? '';
    return Ticket(
      id: j['id'] as String,
      seq: (j['seq'] as num).toInt(),
      receivedAt: DateTime.parse(j['receivedAt'] as String),
      doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
      from: j['from'] as String? ?? '',
      lines: ((j['lines'] as List?) ?? []).map((l) => PrintLine.fromJson(Map<String, dynamic>.from(l as Map))).toList(),
      parsed: p,
    );
  }
}

class Settings {
  Settings({
    this.printerName = 'Køkkenprinter 1',
    this.port = 9100,
    this.protocol = 'escpos',
    this.charset = 'auto',
    this.zoom = 1.0,
    this.layout = 'auto',
    this.view = 'parsed',
    this.warnMinutes = 10,
    this.lateMinutes = 15,
    this.sound = true,
    this.keepDoneHours = 2,
    this.idleFlushMs = 800,
    this.themeMode = 'dark',
    this.palette = 'ctpos',
    this.customAccent = 0xFFED1C24,
    this.customNeutralHue = 0,
    this.customNeutralTint = 0,
    List<String>? allergenWords,
  }) : allergenWords = allergenWords ?? List.of(defaultAllergenWords);

  String printerName;
  int port;
  String protocol; // 'escpos' | 'star'
  String charset; // 'auto' | 'utf8' | 'cp865' | 'cp850' | 'cp858' | 'cp437' | 'cp1252'
  double zoom;
  String layout; // 'auto' | 'landscape' | 'portrait'
  String view; // 'parsed' | 'original'
  int warnMinutes;
  int lateMinutes;
  bool sound;
  double keepDoneHours;
  int idleFlushMs;
  String themeMode; // 'dark' | 'light' | 'auto'
  String palette; // a preset id or 'custom'
  int customAccent; // ARGB
  double customNeutralHue; // 0–360
  double customNeutralTint; // 0–0.4
  List<String> allergenWords;

  static const zooms = [0.8, 1.0, 1.2, 1.45, 1.7, 2.0];

  static const defaultAllergenWords = [
    'allergi', 'allergy', 'allergen', 'allergiker', 'gluten', 'glutenfri', 'laktose', 'laktosefri', 'lactose',
    'mælkeprotein', 'mælk', 'nød', 'nødder', 'nødde', 'jordnød', 'jordnødder', 'peanut', 'peanuts', 'nut', 'nuts',
    'skaldyr', 'shellfish', 'krebsdyr', 'bløddyr', 'selleri', 'celery', 'sennep', 'mustard', 'sesam', 'sesame',
    'soja', 'soy', 'lupin', 'sulfit', 'svovl', 'cøliaki', 'fiskeallergi', 'ægallergi',
  ];

  Settings copy() => Settings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'printerName': printerName,
        'port': port,
        'protocol': protocol,
        'charset': charset,
        'zoom': zoom,
        'layout': layout,
        'view': view,
        'warnMinutes': warnMinutes,
        'lateMinutes': lateMinutes,
        'sound': sound,
        'keepDoneHours': keepDoneHours,
        'idleFlushMs': idleFlushMs,
        'themeMode': themeMode,
        'palette': palette,
        'customAccent': customAccent,
        'customNeutralHue': customNeutralHue,
        'customNeutralTint': customNeutralTint,
        'allergenWords': allergenWords,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final d = Settings();
    return Settings(
      printerName: j['printerName'] as String? ?? d.printerName,
      port: (j['port'] as num?)?.toInt() ?? d.port,
      protocol: j['protocol'] as String? ?? d.protocol,
      charset: j['charset'] as String? ?? d.charset,
      zoom: (j['zoom'] as num?)?.toDouble() ?? d.zoom,
      layout: j['layout'] as String? ?? d.layout,
      view: j['view'] as String? ?? d.view,
      warnMinutes: (j['warnMinutes'] as num?)?.toInt() ?? d.warnMinutes,
      lateMinutes: (j['lateMinutes'] as num?)?.toInt() ?? d.lateMinutes,
      sound: j['sound'] as bool? ?? d.sound,
      keepDoneHours: (j['keepDoneHours'] as num?)?.toDouble() ?? d.keepDoneHours,
      idleFlushMs: (j['idleFlushMs'] as num?)?.toInt() ?? d.idleFlushMs,
      themeMode: j['themeMode'] as String? ?? d.themeMode,
      palette: j['palette'] as String? ?? d.palette,
      customAccent: (j['customAccent'] as num?)?.toInt() ?? d.customAccent,
      customNeutralHue: (j['customNeutralHue'] as num?)?.toDouble() ?? d.customNeutralHue,
      customNeutralTint: (j['customNeutralTint'] as num?)?.toDouble() ?? d.customNeutralTint,
      allergenWords: ((j['allergenWords'] as List?) ?? d.allergenWords).map((e) => '$e').toList(),
    );
  }
}
