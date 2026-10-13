import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../kitchen.dart';
import '../models.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'ticket_card.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key, required this.kitchen});
  final Kitchen kitchen;

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  Kitchen get k => widget.kitchen;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  final _rawOpen = <String>{};
  final _fresh = <String>{};
  final _player = AudioPlayer();
  late StreamSubscription<Ticket> _arrivalSub;
  Timer? _tick;
  Timer? _snackTimer;
  Ticket? _snack;
  double? _zoom;
  int _first = 0;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    k.addListener(_changed);
    _scroll.addListener(_measureSoon);
    _arrivalSub = k.arrivals.listen(_arrived);
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
    _player.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    k.removeListener(_changed);
    _arrivalSub.cancel();
    _tick?.cancel();
    _snackTimer?.cancel();
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _measureSoon();
  }

  void _arrived(Ticket t) {
    _fresh.add(t.id);
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _fresh.remove(t.id));
    });
    if (k.settings.sound) _player.play(AssetSource('chime.wav'));
  }

  double get zoom => _zoom ?? k.settings.zoom;
  double get fs => 20 * zoom;

  void _setZoom(int dir) {
    final zs = Settings.zooms;
    var i = zs.indexWhere((z) => (z - zoom).abs() < .01);
    if (i < 0) i = 1;
    i = (i + dir).clamp(0, zs.length - 1);
    setState(() => _zoom = zs[i]);
    _measureSoon();
  }

  bool _portrait(BoxConstraints c) {
    switch (k.settings.layout) {
      case 'portrait':
        return true;
      case 'landscape':
        return false;
      default:
        return c.maxHeight > c.maxWidth;
    }
  }

  int _minutes(Ticket t) => math.max(0, DateTime.now().difference(t.receivedAt).inMinutes);
  Tone _tone(int m) => toneOf(m, k.settings.warnMinutes, k.settings.lateMinutes);

  // ---------- Paging ----------

  void _measureSoon() => WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  void _measure() {
    if (!mounted) return;
    final rail = _railKey.currentContext?.findRenderObject() as RenderBox?;
    if (rail == null || !rail.hasSize) return;
    final railBox = rail.localToGlobal(Offset.zero) & rail.size;
    final active = k.active;
    var first = 0, last = 0;
    for (var i = 0; i < active.length; i++) {
      final box = _keys[active[i].id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final r = box.localToGlobal(Offset.zero) & box.size;
      final seen = r.intersect(railBox);
      if (seen.width > r.width * .6 && seen.height > math.min(r.height, railBox.height) * .5) {
        if (first == 0) first = i + 1;
        last = i + 1;
      }
    }
    if (first == 0 && active.isNotEmpty) first = last = 1;
    if (first != _first || last != _last) {
      setState(() {
        _first = first;
        _last = last;
      });
    }
  }

  final _railKey = GlobalKey();

  void _page(int dir, bool portrait) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    double delta;
    if (portrait) {
      delta = pos.viewportDimension * .85;
    } else {
      final step = fs * 17 + fs * .6;
      final per = math.max(1, ((pos.viewportDimension - 16) / step).floor());
      delta = per * step;
    }
    final target = (pos.pixels + dir * delta).clamp(0.0, pos.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  // ---------- Done / undo ----------

  void _done(Ticket t) {
    k.markDone(t);
    _snackTimer?.cancel();
    setState(() => _snack = t);
    _snackTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _snack = null);
    });
  }

  void _undo() {
    final t = _snack;
    if (t != null) k.restore(t);
    _snackTimer?.cancel();
    setState(() => _snack = null);
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final active = k.active;
    _keys.removeWhere((id, _) => !active.any((t) => t.id == id));
    return Scaffold(
      key: _scaffold,
      backgroundColor: K.paper,
      endDrawer: _RecallDrawer(kitchen: k, onRestore: (t) => k.restore(t)),
      endDrawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final portrait = _portrait(c);
          return Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(active),
                  Expanded(key: _railKey, child: active.isEmpty ? _empty() : _rail(active, portrait, c)),
                  _bottomBar(active.length, portrait),
                ],
              ),
              if (_snack != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 104,
                  child: Center(child: _snackBar(_snack!)),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _topBar(List<Ticket> active) {
    final dishes = active.fold<int>(0, (a, t) => a + t.dishCount);
    var oldest = -1;
    for (final t in active) {
      if (!t.parsed.isMessage) oldest = math.max(oldest, _minutes(t));
    }
    final st = k.status;
    final ip = k.ips.isNotEmpty ? k.ips.first.address : 'ukendt IP';
    final ok = st.listening && st.error == null;
    final n = active.length;

    return Container(
      color: K.paperBar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/ct-mark.png', height: 44, semanticLabel: 'CT Consult'),
            const SizedBox(width: 16),
            Container(width: 1, height: 40, color: K.outlineVariant),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(k.settings.printerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: K.white)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: ok ? K.ok : K.bad),
                const SizedBox(width: 6),
                Text(
                  ok ? 'Printer $ip:${st.port} · klar' : 'Printer stoppet: ${st.error ?? 'starter…'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ok ? K.ok : K.bad),
                ),
              ]),
            ]),
          ]),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$n', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, height: 1, color: K.white)),
                const SizedBox(width: 10),
                Text(n == 1 ? 'bon venter' : 'bonner venter', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: K.white)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$dishes', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1, color: K.white)),
                const SizedBox(width: 8),
                const Text('retter i alt', style: TextStyle(fontSize: 18, color: K.muted)),
              ]),
              if (oldest >= 0) AgeChip(minutes: oldest, tone: _tone(oldest), fs: 18, prefix: 'Ældste '),
            ],
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _zoomControl(),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _scaffold.currentState?.openEndDrawer(),
              icon: const Icon(Icons.history, size: 24),
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Afsluttede'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(color: K.key, borderRadius: K.radiusPill),
                  child: Text('${k.done.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              height: 58,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage(kitchen: k))),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.settings_outlined, size: 28, semanticLabel: 'Opsætning'),
              ),
            ),
            const SizedBox(width: 16),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, _) => Text(hhmm(DateTime.now()),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: K.white, fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _zoomControl() {
    final zs = Settings.zooms;
    final i = zs.indexWhere((z) => (z - zoom).abs() < .01);
    Widget btn(IconData icon, String label, int dir, bool enabled) => Material(
          color: K.key,
          child: InkWell(
            onTap: enabled ? () => _setZoom(dir) : null,
            child: SizedBox(
              width: 64,
              height: 56,
              child: Icon(icon, size: 30, color: enabled ? K.ink : K.ink.withValues(alpha: .4), semanticLabel: label),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: K.outline), borderRadius: K.radius),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.text_decrease, 'Mindre tekst', -1, i != 0),
        SizedBox(
          width: 76,
          child: Text('${(zoom * 100).round()}%',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: K.white)),
        ),
        btn(Icons.text_increase, 'Større tekst', 1, i != zs.length - 1),
      ]),
    );
  }

  Widget _card(Ticket t, bool fill) {
    final m = _minutes(t);
    final rawDefault = k.settings.view == 'original';
    return TicketCard(
      key: _keys.putIfAbsent(t.id, GlobalKey.new),
      ticket: t,
      fs: fs,
      minutes: m,
      tone: _tone(m),
      showRaw: rawDefault ? !_rawOpen.contains(t.id) : _rawOpen.contains(t.id),
      fillHeight: fill,
      fresh: _fresh.contains(t.id),
      onDone: () => _done(t),
      onToggleRaw: () => setState(() => _rawOpen.contains(t.id) ? _rawOpen.remove(t.id) : _rawOpen.add(t.id)),
    );
  }

  Widget _rail(List<Ticket> active, bool portrait, BoxConstraints c) {
    final gap = fs * .6;
    if (!portrait) {
      return ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        itemCount: active.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (_, i) => SizedBox(width: fs * 17, child: _card(active[i], true)),
      );
    }
    // Portrait: a grid of cards as tall as their content, scrolling up and down.
    final width = c.maxWidth - 32;
    final cols = math.max(1, ((width + gap) / (fs * 17 + gap)).floor());
    final cardW = (width - gap * (cols - 1)) / cols;
    final rows = <Widget>[];
    for (var r = 0; r < active.length; r += cols) {
      final slice = active.sublist(r, math.min(r + cols, active.length));
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) SizedBox(width: gap),
              SizedBox(width: cardW, child: j < slice.length ? _card(slice[j], false) : null),
            ],
          ],
        ),
      ));
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      child: Column(children: rows),
    );
  }

  Widget _empty() => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image(image: AssetImage('assets/ct-mark.png'), height: 110, semanticLabel: 'CT Consult'),
          SizedBox(height: 32),
          Icon(Icons.check_circle_outline, size: 56, color: K.ok),
          SizedBox(height: 12),
          Text('Ingen bonner venter', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: K.white)),
          SizedBox(height: 8),
          Text('Nye bonner vises her, så snart printeren modtager dem.', style: TextStyle(fontSize: 18, color: K.muted)),
        ]),
      );

  Widget _bottomBar(int n, bool portrait) {
    final first = n == 0 ? 0 : _first.clamp(1, n);
    final last = n == 0 ? 0 : _last.clamp(first, n);
    final more = n - last;
    Widget nav(String label, IconData icon, int dir, bool enabled, {bool iconFirst = true}) => SizedBox(
          height: 64,
          child: FilledButton(
            onPressed: enabled ? () => _page(dir, portrait) : null,
            style: FilledButton.styleFrom(
              backgroundColor: K.key,
              foregroundColor: K.ink,
              disabledBackgroundColor: K.key.withValues(alpha: .5),
              disabledForegroundColor: K.ink.withValues(alpha: .4),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (iconFirst) Icon(icon, size: 32),
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (!iconFirst) Icon(icon, size: 32),
            ]),
          ),
        );
    final active = k.active;
    return Container(
      color: K.paperBar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        nav('Forrige', portrait ? Icons.expand_less : Icons.chevron_left, -1, n > 0 && first > 1),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: n == 0 ? 'Ingen bonner' : 'Viser $first–$last af $n', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (n > 0)
                  TextSpan(
                    text: ' · ${more > 0 ? '$more flere ${portrait ? 'længere nede' : 'til højre'}' : 'alle vises'}',
                    style: const TextStyle(color: K.muted),
                  ),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: K.white),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (var i = 0; i < active.length; i++)
                Container(
                  width: 22,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i + 1 >= first && i + 1 <= last ? K.accent : K.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ]),
          ]),
        ),
        nav('Næste', portrait ? Icons.expand_more : Icons.chevron_right, 1, n > 0 && last < n, iconFirst: false),
      ]),
    );
  }

  Widget _snackBar(Ticket t) {
    final head = headOf(t);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 10, 10, 10),
      decoration: const BoxDecoration(color: K.inverseSurface, borderRadius: K.radius14),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text('${head.title} · bon ${t.number} ${t.parsed.isMessage ? 'er læst' : 'er færdig'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: K.inverseInk)),
        ),
        const SizedBox(width: 20),
        FilledButton.icon(onPressed: _undo, icon: const Icon(Icons.undo), label: const Text('Fortryd')),
      ]),
    );
  }
}

class _RecallDrawer extends StatelessWidget {
  const _RecallDrawer({required this.kitchen, required this.onRestore});
  final Kitchen kitchen;
  final void Function(Ticket) onRestore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kitchen,
      builder: (context, _) {
        final done = kitchen.done;
        return Drawer(
          width: math.min(560, MediaQuery.sizeOf(context).width),
          backgroundColor: K.card,
          shape: const RoundedRectangleBorder(),
          child: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: K.outlineVariant))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Afsluttede bonner', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: K.white)),
                      SizedBox(height: 4),
                      Text('Hent en bon tilbage, hvis den blev fjernet ved en fejl.', style: TextStyle(fontSize: 15, color: K.muted)),
                    ]),
                  ),
                  IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: K.key, foregroundColor: K.ink, minimumSize: const Size(64, 64), shape: const RoundedRectangleBorder(borderRadius: K.radius)),
                    icon: const Icon(Icons.close, size: 32, semanticLabel: 'Luk'),
                  ),
                ]),
              ),
              Expanded(
                child: done.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Ingen afsluttede bonner endnu.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: K.muted)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        itemCount: done.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final t = done[i];
                          final head = headOf(t);
                          final count = t.dishCount;
                          final summary = t.parsed.isMessage
                              ? t.parsed.message
                              : t.parsed.sections.expand((s) => s.items).map((it) => '${it.qty} × ${it.name}').join(', ');
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: K.paper, borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(head.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: K.white)),
                                  const SizedBox(height: 4),
                                  Text('Bon ${t.number}${count > 0 ? ' · $count retter' : ''} · færdig ${hhmm(t.doneAt!)}',
                                      style: const TextStyle(fontSize: 15, color: K.muted)),
                                  const SizedBox(height: 4),
                                  Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: K.ink)),
                                ]),
                              ),
                              const SizedBox(width: 16),
                              FilledButton.icon(onPressed: () => onRestore(t), icon: const Icon(Icons.undo), label: const Text('Hent tilbage')),
                            ]),
                          );
                        },
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
