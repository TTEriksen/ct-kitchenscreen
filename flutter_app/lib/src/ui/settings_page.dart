import 'package:flutter/material.dart';

import '../kitchen.dart';
import '../models.dart';
import 'color_settings.dart';
import 'logo_settings.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.kitchen});
  final Kitchen kitchen;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Settings s = widget.kitchen.settings.copy();
  late final _logos = LogoDraft(widget.kitchen);
  late final _name = TextEditingController(text: s.printerName);
  late final _port = TextEditingController(text: '${s.port}');
  late final _warn = TextEditingController(text: '${s.warnMinutes}');
  late final _late = TextEditingController(text: '${s.lateMinutes}');
  late final _keep = TextEditingController(text: _num(s.keepDoneHours));
  late final _words = TextEditingController(text: s.allergenWords.join(', '));
  late final _printerHost = TextEditingController(text: s.printerHost);
  late final _printerPort = TextEditingController(text: '${s.printerPort}');
  bool _testing = false;
  String _msg = '';

  static String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  void initState() {
    super.initState();
    widget.kitchen.refreshIps();
  }

  @override
  void dispose() {
    for (final c in [_name, _port, _warn, _late, _keep, _words, _printerHost, _printerPort]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final next = s.copy()
      ..printerName = _name.text.trim().isEmpty ? 'Køkkenprinter 1' : _name.text.trim()
      ..port = (int.tryParse(_port.text) ?? 9100).clamp(1, 65535)
      ..warnMinutes = (int.tryParse(_warn.text) ?? 10).clamp(1, 240)
      ..lateMinutes = (int.tryParse(_late.text) ?? 15).clamp(1, 240)
      ..keepDoneHours = (double.tryParse(_keep.text.replaceAll(',', '.')) ?? 0).clamp(0, 48)
      ..printerHost = _printerHost.text.trim()
      ..printerPort = (int.tryParse(_printerPort.text) ?? 9100).clamp(1, 65535)
      ..allergenWords = _words.text.split(RegExp(r'[,\n]')).map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
    await _logos.save(widget.kitchen);
    await widget.kitchen.saveSettings(next);
    setState(() => _msg = 'Gemt');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.kitchen,
      builder: (context, _) {
        final k = widget.kitchen;
        final st = k.status;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 82,
            leadingWidth: 84,
            leading: Padding(
              padding: EdgeInsets.only(left: 16),
              child: Center(
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: K.key, foregroundColor: K.ink, minimumSize: Size(56, 56), shape: RoundedRectangleBorder(borderRadius: K.radius)),
                  icon: Icon(Icons.arrow_back, size: 30, semanticLabel: 'Tilbage til køkkenskærmen'),
                ),
              ),
            ),
            title: Text('Opsætning', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            actions: [
              Container(
                margin: EdgeInsets.only(right: 16),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(borderRadius: K.radiusPill, border: Border.all(color: st.listening ? K.ok : K.bad)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(st.listening ? Icons.check_circle_outline : Icons.error_outline, color: st.listening ? K.ok : K.bad, size: 20),
                  SizedBox(width: 6),
                  Text(st.listening ? 'Lytter på port ${st.port}' : (st.error ?? 'Lytter ikke'),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: st.listening ? K.ok : K.bad)),
                ]),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 900;
              final emulation = _panel(Icons.lan_outlined, 'Printer-emulering', [
                Text(
                  'Skærmen svarer som en kitchen printer. Kassen sender bonner til denne enheds IP-adresse og port, som den ellers ville printe til.',
                  style: TextStyle(fontSize: 15, height: 1.4, color: K.muted),
                ),
                _field('Printernavn', _name),
                _row([
                  _field('Port', _port, number: true),
                  _drop('Protokol', s.protocol, {'escpos': 'ESC/POS (Epson m.fl.)', 'star': 'Star Line'}, (v) => s.protocol = v),
                ]),
                _drop('Tegnsæt', s.charset, {
                  'auto': 'Automatisk',
                  'cp865': 'PC865 nordisk',
                  'cp850': 'PC850',
                  'cp858': 'PC858 (med €)',
                  'cp1252': 'Windows-1252',
                  'utf8': 'UTF-8',
                  'cp437': 'PC437',
                }, (v) => s.charset = v),
                Text('Denne enheds IP-adresser', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: K.ink)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (k.ips.isEmpty) Text('Ingen netværksforbindelse fundet', style: TextStyle(color: K.muted)),
                  for (final ip in k.ips)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: K.paper, borderRadius: K.radius),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: ip.address, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: K.strong)),
                        TextSpan(text: '  ${ip.iface}', style: TextStyle(fontSize: 13, color: K.muted)),
                      ])),
                    ),
                ]),
                Text(
                  'Giv tabletten en fast IP-adresse i Wi-Fi-indstillingerne (eller reservér den i routeren), og indtast den samme adresse og port i kassen.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: K.muted),
                ),
              ]);
              final left = Column(children: [
                emulation,
                const SizedBox(height: 16),
                _printerPanel(k),
              ]);
              final right = Column(children: [
                _panel(Icons.tune, 'Visning', [
                  _row([
                    _drop('Tekststørrelse', '${s.zoom}', {for (final z in Settings.zooms) '$z': '${(z * 100).round()}%'}, (v) => s.zoom = double.parse(v)),
                    _drop('Layout', s.layout, {'auto': 'Automatisk', 'landscape': 'Liggende', 'portrait': 'Stående'}, (v) => s.layout = v),
                  ]),
                  _row([
                    _field('Gul efter (min)', _warn, number: true),
                    _field('Rød efter (min)', _late, number: true),
                  ]),
                  _row([
                    _drop('Bonvisning', s.view, {'parsed': 'Opdelt', 'original': 'Original bon'}, (v) => s.view = v),
                    _field('Gem afsluttede (timer, 0 = hele dagen)', _keep, number: true),
                  ]),
                  _row([
                    _timeField('Ny arbejdsdag kl.', s.dayStart, (v) => s.dayStart = v),
                    const SizedBox(),
                  ]),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.notifications_active_outlined, color: K.ink),
                      title: Text('Lyd ved ny bon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: K.ink)),
                      value: s.sound,
                      onChanged: (v) => setState(() => s.sound = v),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.history, color: K.ink),
                      title: Text('Ryd også ventende bonner fra dagen før',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: K.ink)),
                      value: s.dayResetActive,
                      onChanged: (v) => setState(() => s.dayResetActive = v),
                    ),
                  ),
                  Text('Ved ny arbejdsdag ryddes Afsluttede, så tælleren starter forfra.',
                      style: TextStyle(fontSize: 14, color: K.muted)),
                  _field('Allergen-ord (adskilt med komma)', _words, lines: 3),
                ]),
                SizedBox(height: 16),
                _panel(Icons.receipt_long_outlined, 'Drift', [
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        k.sendTestTicket();
                        setState(() => _msg = 'Testbon sendt til skærmen');
                      },
                      icon: Icon(Icons.print_outlined),
                      label: Text('Modtag testbon'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: K.card,
                            title: Text('Ryd alle bonner?'),
                            content: Text('Alle bonner fjernes, også de afsluttede.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annullér')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('Ryd alle')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          k.clearAll();
                          setState(() => _msg = 'Alle bonner er fjernet');
                        }
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: K.bad, side: BorderSide(color: K.bad)),
                      icon: Icon(Icons.delete_outline),
                      label: Text('Ryd alle bonner'),
                    ),
                  ]),
                  Text(
                    st.lastJobAt != null ? 'Sidste bon modtaget kl. ${hhmm(st.lastJobAt!)} · ${st.jobs} siden start' : 'Ingen bonner modtaget siden start.',
                    style: TextStyle(fontSize: 14, color: K.muted),
                  ),
                ]),
              ]);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ColorSettings(settings: s, onChanged: () => setState(() {})),
                  const SizedBox(height: 16),
                  LogoSettings(settings: s, draft: _logos, onChanged: () => setState(() {})),
                  const SizedBox(height: 16),
                  wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: left),
                          const SizedBox(width: 16),
                          Expanded(child: right),
                        ])
                      : Column(children: [left, const SizedBox(height: 16), right]),
                ]),
              );
            }),
          ),
          bottomNavigationBar: Container(
            color: K.paperBar,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: Row(children: [
              Expanded(child: Text(_msg, style: TextStyle(fontSize: 16, color: K.muted))),
              OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text('Annullér')),
              SizedBox(width: 12),
              FilledButton.icon(onPressed: _save, icon: Icon(Icons.check), label: Text('Gem')),
            ]),
          ),
        );
      },
    );
  }

  String _printerInfoText(Kitchen k) {
    final pi = k.printerInfo;
    if (pi == null) return 'Printerens model og bredde aflæses ved første udskrift eller testudskrift.';
    final (p, info) = pi;
    final how = switch (p.source) {
      'printer' => 'aflæst fra printeren',
      'setting' => 'valgt i opsætningen',
      _ => 'printeren oplyste ikke sin model, så den sikre bredde bruges. Vælg papirbredde, hvis bonnen skal bruge hele papiret',
    };
    return 'Printer: ${info.name.isEmpty ? 'ukendt model' : info.name} · ${p.paper} · ${p.cols} tegn pr. linje ($how).';
  }

  Widget _printerPanel(Kitchen k) {
    final last = k.lastPrint;
    Widget toggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(icon, color: K.ink),
            title: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: K.ink)),
            value: value,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        );
    return _panel(Icons.print_outlined, 'Fysisk printer', [
      Text('Print bonner på en rigtig netværksprinter (ESC/POS, fx Epson eller Star) i køkkenet. Før hver udskrift spørges printeren om model og papir, og bonnen sættes op til hele papirets bredde.',
          style: TextStyle(fontSize: 15, height: 1.4, color: K.muted)),
      toggle('Brug printer', Icons.print_outlined, s.printerEnabled, (v) => s.printerEnabled = v),
      _row([
        _field('Printerens IP-adresse', _printerHost),
        _field('Port', _printerPort, number: true),
      ]),
      _drop('Papirbredde', s.printerPaper, {
        'auto': 'Automatisk (spørg printeren)',
        '80-48': '80 mm · 48 tegn',
        '80-42': '80 mm · 42 tegn',
        '58-32': '58 mm · 32 tegn',
      }, (v) => s.printerPaper = v),
      Text(_printerInfoText(k), style: TextStyle(fontSize: 14, height: 1.4, color: K.muted)),
      toggle('Udskriv alle nye bonner automatisk', Icons.receipt_long_outlined, s.autoPrint, (v) => s.autoPrint = v),
      Text('Ellers printes en bon fra den store visning: tryk på bonnen, og tryk Print. En genudskrift får overskriften KOPI.',
          style: TextStyle(fontSize: 14, height: 1.4, color: K.muted)),
      Row(children: [
        OutlinedButton.icon(
          onPressed: _testing
              ? null
              : () async {
                  setState(() => _testing = true);
                  final test = s.copy()
                    ..printerHost = _printerHost.text.trim()
                    ..printerPort = (int.tryParse(_printerPort.text) ?? 9100).clamp(1, 65535)
                    ..printerPaper = s.printerPaper;
                  await k.testPrint(test);
                  if (mounted) setState(() => _testing = false);
                },
          icon: const Icon(Icons.print_outlined),
          label: Text(_testing ? 'Printer…' : 'Testudskrift'),
        ),
      ]),
      Text(
        last == null
            ? 'Ingen udskrifter endnu.'
            : last.ok
                ? '${last.what} printet kl. ${hhmm(last.at)}'
                : '${last.what} fejlede: ${last.error}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: last == null ? K.muted : (last.ok ? K.ok : K.bad)),
      ),
    ]);
  }

  Widget _panel(IconData icon, String title, List<Widget> children) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(color: K.card, borderRadius: K.radius14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: K.primary, size: 26),
            SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: K.strong)),
          ]),
          for (final c in children) ...[SizedBox(height: 16), c],
        ]),
      );

  /// A time of day, chosen with the clock picker (24-hour).
  Widget _timeField(String label, String value, void Function(String) onChanged) {
    return InkWell(
      borderRadius: K.radiusControl,
      onTap: () async {
        final parts = value.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 6, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
        );
        if (picked != null) {
          setState(() => onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule_outlined)),
        child: Text(value, style: TextStyle(fontSize: 20, color: K.ink)),
      ),
    );
  }

  Widget _row(List<Widget> children) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: 14),
          Expanded(child: children[i]),
        ],
      ]);

  Widget _field(String label, TextEditingController c, {bool number = false, int lines = 1}) => TextField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(fontSize: lines > 1 ? 16 : 20, color: K.ink),
        decoration: InputDecoration(labelText: label),
      );

  Widget _drop(String label, String value, Map<String, String> options, void Function(String) onChanged) => DropdownButtonFormField<String>(
        initialValue: options.containsKey(value) ? value : options.keys.first,
        isExpanded: true,
        dropdownColor: K.key,
        style: TextStyle(fontSize: 20, color: K.ink),
        decoration: InputDecoration(labelText: label),
        items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          if (v != null) setState(() => onChanged(v));
        },
      );
}
