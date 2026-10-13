import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'printer/escpos.dart';
import 'printer/parser.dart';
import 'printer/samples.dart';

class PrinterStatus {
  const PrinterStatus({this.listening = false, this.port, this.error, this.lastJobAt, this.jobs = 0});
  final bool listening;
  final int? port;
  final String? error;
  final DateTime? lastJobAt;
  final int jobs;

  PrinterStatus copyWith({bool? listening, int? port, String? error, bool clearError = false, DateTime? lastJobAt, int? jobs}) =>
      PrinterStatus(
        listening: listening ?? this.listening,
        port: port ?? this.port,
        error: clearError ? null : (error ?? this.error),
        lastJobAt: lastJobAt ?? this.lastJobAt,
        jobs: jobs ?? this.jobs,
      );
}

/// Everything the screen shows: tickets, settings and the emulated printer.
/// The tablet itself is the printer: it listens on a TCP port (9100) like a
/// network kitchen printer, and each paper cut in a job becomes a ticket.
class Kitchen extends ChangeNotifier {
  Kitchen._(this._dir);

  final Directory _dir;
  final List<Ticket> _tickets = [];
  Settings settings = Settings();
  PrinterStatus status = const PrinterStatus();
  List<({String iface, String address})> ips = [];
  int _seq = 0;
  ServerSocket? _server;
  Timer? _saveTimer;
  Timer? _purgeTimer;
  final _arrivals = StreamController<Ticket>.broadcast();

  /// New tickets as they arrive (for the chime).
  Stream<Ticket> get arrivals => _arrivals.stream;

  static Future<Kitchen> open() async {
    final dir = await _dataDir();
    final k = Kitchen._(dir);
    await k._load();
    await k.startPrinter();
    k.refreshIps();
    k._purgeTimer = Timer.periodic(const Duration(minutes: 1), (_) => k._purge());
    return k;
  }

  /// The app's own private storage, found from its temp folder so no
  /// platform plugin is needed: iOS keeps it in Library/Application Support,
  /// Android in the app's files folder.
  static Future<Directory> _dataDir() async {
    final root = Directory.systemTemp.parent.path;
    final dir = Directory(Platform.isIOS || Platform.isMacOS ? '$root/Library/Application Support' : '$root/files');
    await dir.create(recursive: true);
    return dir;
  }

  File get _ticketsFile => File('${_dir.path}/tickets.json');
  File get _settingsFile => File('${_dir.path}/settings.json');

  Future<void> _load() async {
    try {
      if (await _settingsFile.exists()) {
        settings = Settings.fromJson(jsonDecode(await _settingsFile.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {/* keep defaults */}
    try {
      if (await _ticketsFile.exists()) {
        final j = jsonDecode(await _ticketsFile.readAsString()) as Map<String, dynamic>;
        _seq = (j['seq'] as num?)?.toInt() ?? 0;
        for (final t in (j['tickets'] as List? ?? [])) {
          _tickets.add(Ticket.fromJson(Map<String, dynamic>.from(t as Map)));
        }
      }
    } catch (_) {/* start empty */}
    _purge();
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      final data = jsonEncode({'seq': _seq, 'tickets': _tickets.map((t) => t.toJson()).toList()});
      final tmp = File('${_ticketsFile.path}.tmp');
      await tmp.writeAsString(data, flush: true);
      await tmp.rename(_ticketsFile.path);
    });
  }

  List<Ticket> get active => _tickets.where((t) => !t.isDone).toList()..sort((a, b) => a.seq.compareTo(b.seq));
  List<Ticket> get done => _tickets.where((t) => t.isDone).toList()..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

  void markDone(Ticket t) {
    t.doneAt = DateTime.now();
    _save();
    notifyListeners();
  }

  void restore(Ticket t) {
    t.doneAt = null;
    _save();
    notifyListeners();
  }

  void clearAll() {
    _tickets.clear();
    _save();
    notifyListeners();
  }

  void _purge() {
    final keep = Duration(minutes: (settings.keepDoneHours * 60).round());
    final now = DateTime.now();
    final before = _tickets.length;
    _tickets.removeWhere((t) => t.doneAt != null && now.difference(t.doneAt!) > keep);
    if (_tickets.length != before) {
      _save();
      notifyListeners();
    }
  }

  Future<void> saveSettings(Settings next) async {
    final portChanged = next.port != settings.port;
    settings = next;
    await _settingsFile.writeAsString(jsonEncode(settings.toJson()));
    if (portChanged) await startPrinter();
    _purge();
    notifyListeners();
  }

  // ---------- Printer emulation ----------

  Future<void> startPrinter() async {
    await _server?.close();
    _server = null;
    final port = settings.port;
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _server = server;
      status = status.copyWith(listening: true, port: port, clearError: true);
      server.listen(_handle, onError: (Object e) {
        status = status.copyWith(listening: false, error: '$e');
        notifyListeners();
      });
    } on SocketException catch (e) {
      status = status.copyWith(listening: false, port: port, error: _describe(e, port));
    }
    notifyListeners();
  }

  String _describe(SocketException e, int port) {
    final code = e.osError?.errorCode;
    if (code == 48 || code == 98) return 'Port $port er optaget af et andet program';
    if (code == 13) return 'Ingen adgang til port $port';
    return e.message;
  }

  void _handle(Socket sock) {
    final from = sock.remoteAddress.address;
    final chunks = BytesBuilder(copy: false);
    Timer? idle;
    void flush() {
      idle?.cancel();
      if (chunks.isEmpty) return;
      ingest(chunks.takeBytes(), from: from);
    }

    sock.listen(
      (data) {
        final reply = realtimeReplies(data);
        if (reply != null) sock.add(reply);
        chunks.add(data);
        idle?.cancel();
        idle = Timer(Duration(milliseconds: settings.idleFlushMs), flush);
      },
      onDone: () {
        flush();
        sock.destroy();
      },
      onError: (_) {
        flush();
        sock.destroy();
      },
      cancelOnError: true,
    );
  }

  /// Decode a job and store each page as a ticket. Also used for test tickets.
  int ingest(List<int> bytes, {String from = 'test'}) {
    List<List<PrintLine>> pages;
    try {
      pages = decodeJob(bytes, protocol: settings.protocol, charset: settings.charset);
    } catch (e) {
      debugPrint('Kunne ikke læse bon: $e');
      return 0;
    }
    for (final lines in pages) {
      _seq++;
      final t = Ticket(
        id: '${DateTime.now().microsecondsSinceEpoch}-$_seq',
        seq: _seq,
        receivedAt: DateTime.now(),
        from: from,
        lines: lines,
        parsed: parseTicket(lines, allergenWords: settings.allergenWords),
      );
      _tickets.add(t);
      _arrivals.add(t);
    }
    if (pages.isNotEmpty) {
      status = status.copyWith(lastJobAt: DateTime.now(), jobs: status.jobs + pages.length);
      _save();
      notifyListeners();
    }
    return pages.length;
  }

  void sendTestTicket() => ingest(nextSample());

  Future<void> refreshIps() async {
    try {
      final list = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      ips = [
        for (final i in list)
          for (final a in i.addresses) (iface: i.name, address: a.address),
      ];
      notifyListeners();
    } catch (_) {/* no network */}
  }

  @override
  void dispose() {
    _server?.close();
    _saveTimer?.cancel();
    _purgeTimer?.cancel();
    _arrivals.close();
    super.dispose();
  }
}
