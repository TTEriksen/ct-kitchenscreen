import 'package:flutter/material.dart';

import '../models.dart';
import 'theme.dart';

/// Title for a ticket: table number, take away, message, or ticket number.
({String label, String value, String title}) headOf(Ticket t) {
  final p = t.parsed;
  if (p.isMessage) return (label: 'Besked', value: '', title: 'Besked');
  if (p.table != null) return (label: 'Bord', value: p.table!, title: 'Bord ${p.table}');
  if (p.takeaway != null) return (label: p.takeaway!, value: '', title: p.takeaway!);
  return (label: 'Bon', value: t.number, title: 'Bon ${t.number}');
}

class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    required this.fs,
    required this.minutes,
    required this.tone,
    required this.showRaw,
    required this.fillHeight,
    required this.onDone,
    required this.onToggleRaw,
    this.fresh = false,
  });

  final Ticket ticket;

  /// Base font size: 20 px at 100 % zoom. Everything on the card scales with it.
  final double fs;
  final int minutes;
  final Tone tone;
  final bool showRaw;

  /// Landscape: the card fills the rail's height and its body scrolls.
  /// Portrait: the card is as tall as its content.
  final bool fillHeight;
  final bool fresh;
  final VoidCallback onDone;
  final VoidCallback onToggleRaw;

  @override
  Widget build(BuildContext context) {
    final p = ticket.parsed;
    final head = headOf(ticket);
    final late = tone == Tone.late;
    final courses = p.sections.where((s) => s.course != null).toList();
    final pill = p.sections.length == 1 && courses.length == 1
        ? courses.first.course!
        : (p.table != null && p.takeaway != null ? p.takeaway! : null);

    final meta = [
      'Bon ${ticket.number}',
      if (p.guests != null) '${p.guests} pers.',
      if (p.waiter != null) p.waiter!,
      p.time ?? hhmm(ticket.receivedAt),
    ].join(' · ');

    final body = Padding(
      padding: EdgeInsets.fromLTRB(fs * .8, fs * .7, fs * .8, fs * .7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: showRaw ? [_raw()] : _parsedBody(p),
      ),
    );

    final card = AnimatedContainer(
      duration: Duration(milliseconds: 900),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: K.radius,
        border: Border.all(
          color: fresh ? K.ok : (late ? K.bad : (p.isMessage ? K.accent : K.outlineVariant)),
          width: fresh || late || p.isMessage ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Head: table number and waiting time.
          Container(
            color: K.paperBar,
            padding: EdgeInsets.symmetric(horizontal: fs * .8, vertical: fs * .5),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(head.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: fs * .95, fontWeight: FontWeight.w600, color: K.muted)),
                      ),
                      if (head.value.isNotEmpty) ...[
                        SizedBox(width: fs * .35),
                        Flexible(
                          child: Text(head.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: fs * 2.1, fontWeight: FontWeight.w800, height: 1, color: K.strong)),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: fs * .5),
                AgeChip(minutes: minutes, tone: tone, fs: fs * .95),
              ],
            ),
          ),
          // Meta line, course and the original-printout toggle.
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: K.outlineVariant))),
            padding: EdgeInsets.only(left: fs * .8, right: fs * .3),
            child: Row(
              children: [
                Expanded(child: Text(meta, style: TextStyle(fontSize: fs * .8, color: K.muted))),
                if (pill != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: fs * .5, vertical: fs * .1),
                    decoration: BoxDecoration(color: K.primaryContainer, borderRadius: K.radiusPill),
                    child: Text(pill, style: TextStyle(fontSize: fs * .8, fontWeight: FontWeight.w700, color: K.onPrimaryContainer)),
                  ),
                IconButton(
                  onPressed: onToggleRaw,
                  tooltip: 'Vis original bon',
                  isSelected: showRaw,
                  style: IconButton.styleFrom(minimumSize: Size(48, 48)),
                  color: showRaw ? K.primary : K.muted,
                  icon: Icon(Icons.receipt_long_outlined, size: fs * 1.1),
                ),
              ],
            ),
          ),
          if (fillHeight) Expanded(child: SingleChildScrollView(child: body)) else body,
          Padding(
            padding: EdgeInsets.fromLTRB(fs * .8, 0, fs * .8, fs * .8),
            child: SizedBox(
              height: (fs * 3.1).clamp(64, 200),
              child: FilledButton.icon(
                onPressed: onDone,
                icon: Icon(Icons.check_circle_outline, size: fs * 1.3),
                label: Text(p.isMessage ? 'Læst' : 'Færdig',
                    style: TextStyle(fontSize: (fs * 1.05).clamp(17, 60), fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(label: '${head.title}, $minutes min', container: true, child: card);
  }

  List<Widget> _parsedBody(ParsedTicket p) {
    final gap = SizedBox(height: fs * .6);
    final out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(gap);
      out.add(w);
    }

    if (p.allergens.isNotEmpty) {
      add(Container(
        padding: EdgeInsets.all(fs * .6),
        decoration: BoxDecoration(color: K.badGround, borderRadius: K.radius, border: Border.all(color: K.bad, width: 2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_outlined, color: K.bad, size: fs * 1.35),
              SizedBox(width: fs * .35),
              Text('Allergi', style: TextStyle(fontSize: fs * 1.05, fontWeight: FontWeight.w800, color: K.bad)),
            ]),
            for (final a in p.allergens)
              Padding(
                padding: EdgeInsets.only(top: fs * .3),
                child: Text(a, style: TextStyle(fontSize: fs * 1.1, fontWeight: FontWeight.w700, height: 1.25, color: K.strong)),
              ),
          ],
        ),
      ));
    }

    if (p.isMessage) {
      add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, color: K.primary, size: fs * 1.6),
          SizedBox(width: fs * .5),
          Expanded(
            child: Text(p.message, style: TextStyle(fontSize: fs * 1.3, fontWeight: FontWeight.w600, height: 1.3, color: K.strong)),
          ),
        ],
      ));
    }

    final showCourse = p.sections.length > 1;
    for (final s in p.sections) {
      if (showCourse && s.course != null) {
        add(Text(s.course!, style: TextStyle(fontSize: fs * .85, fontWeight: FontWeight.w700, color: K.primary)));
      }
      for (final it in s.items) {
        add(Container(
          padding: EdgeInsets.only(bottom: fs * .45),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: K.key))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fs * 1.3 * 2.0,
                    child: Text('${it.qty} ×',
                        style: TextStyle(fontSize: fs * 1.3, fontWeight: FontWeight.w800, height: 1.2, color: K.strong,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  SizedBox(width: fs * .5),
                  Expanded(
                    child: Text(it.name, style: TextStyle(fontSize: fs * 1.3, fontWeight: FontWeight.w600, height: 1.2, color: K.ink)),
                  ),
                  if (it.allergy)
                    Padding(
                      padding: EdgeInsets.only(left: fs * .3, top: fs * .1),
                      child: Icon(Icons.warning_amber_outlined, color: K.bad, size: fs * 1.3, semanticLabel: 'Allergi'),
                    ),
                ],
              ),
              for (final m in it.mods)
                Padding(
                  padding: EdgeInsets.only(left: fs * 3.1, top: fs * .15),
                  child: Text(m.text,
                      style: TextStyle(fontSize: fs * 1.05, fontWeight: FontWeight.w600, height: 1.25, color: m.allergy ? K.bad : K.primary)),
                ),
            ],
          ),
        ));
      }
    }

    for (final n in p.notes) {
      add(Container(
        padding: EdgeInsets.all(fs * .6),
        decoration: BoxDecoration(color: K.primaryContainer, borderRadius: K.radius),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.edit_note, color: K.onPrimaryContainer, size: fs * 1.4),
            SizedBox(width: fs * .4),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Note: ', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: n),
                ]),
                style: TextStyle(fontSize: fs * 1.1, fontWeight: FontWeight.w600, height: 1.25, color: K.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ));
    }
    for (final x in p.extra) {
      add(Text(x, style: TextStyle(fontSize: fs * .95, color: K.muted, height: 1.3)));
    }
    return out;
  }

  Widget _raw() {
    return Container(
      padding: EdgeInsets.all(fs * .6),
      decoration: BoxDecoration(color: K.paper, borderRadius: K.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in ticket.lines)
            Container(
              color: l.inverse ? K.ink : null,
              child: Text(
                l.text.isEmpty ? ' ' : l.text,
                textAlign: l.align == 'center' ? TextAlign.center : (l.align == 'right' ? TextAlign.right : TextAlign.left),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: K.mono,
                  fontSize: fs * .85 * (l.big ? 1.45 : 1),
                  height: 1.35,
                  fontWeight: l.big || l.bold || l.red ? FontWeight.w700 : FontWeight.w400,
                  color: l.inverse ? K.paper : (l.red ? K.bad : (l.bold ? K.strong : K.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AgeChip extends StatelessWidget {
  const AgeChip({super.key, required this.minutes, required this.tone, required this.fs, this.prefix = ''});
  final int minutes;
  final Tone tone;
  final double fs;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final late = tone == Tone.late;
    final color = switch (tone) { Tone.ok => K.ok, Tone.warn => K.warn, Tone.late => K.bad };
    final ink = late ? K.onBad : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fs * .55, vertical: fs * .2),
      decoration: BoxDecoration(
        color: late ? K.bad : null,
        borderRadius: K.radiusPill,
        border: Border.all(color: color, width: 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(late ? Icons.alarm : Icons.schedule_outlined, size: fs * 1.15, color: ink),
        SizedBox(width: fs * .25),
        Text('$prefix$minutes min',
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, color: ink, fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
