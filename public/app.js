'use strict';

(function () {
  // ---------- Icons (inline stroke SVG, so the screen works without internet) ----------
  const P = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
  const ICONS = {
    check: P('<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16.5 9.5"/>'),
    warning: P('<path d="M12 3.5L22 20H2z"/><path d="M12 10v4.5"/><path d="M12 17.5v.01"/>'),
    clock: P('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>'),
    history: P('<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1"/><path d="M3 4.5V9h4.5"/><path d="M12 7.5V12l3 2"/>'),
    settings: P('<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>'),
    sliders: P('<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>'),
    left: P('<path d="M15 5l-7 7 7 7"/>'),
    right: P('<path d="M9 5l7 7-7 7"/>'),
    up: P('<path d="M5 15l7-7 7 7"/>'),
    down: P('<path d="M5 9l7 7 7-7"/>'),
    back: P('<path d="M19 12H5"/><path d="M11 6l-6 6 6 6"/>'),
    undo: P('<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>'),
    close: P('<path d="M6 6l12 12M18 6L6 18"/>'),
    note: P('<path d="M5 4h14v11l-5 5H5z"/><path d="M14 20v-5h5"/><path d="M8.5 9h7M8.5 12.5h4"/>'),
    megaphone: P('<path d="M3 10v4h3l7 5V5L6 10z"/><path d="M17 9a4 4 0 0 1 0 6"/><path d="M19.5 6.5a7.5 7.5 0 0 1 0 11"/>'),
    pot: P('<path d="M4 10h16v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z"/><path d="M2 10h20"/><path d="M9 3.5c-.8 1 .8 2 0 3M15 3.5c-.8 1 .8 2 0 3M12 3c-.8 1 .8 2 0 3"/>'),
    receipt: P('<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>'),
    print: P('<path d="M7 9V3h10v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M7 14h10v7H7z"/>'),
    sound: P('<path d="M4 9.5v5h4l5 4v-13l-5 4z"/><path d="M16.5 9a4 4 0 0 1 0 6"/><path d="M19 6.5a7.5 7.5 0 0 1 0 11"/>'),
    fullscreen: P('<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>'),
    image: P('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-9 9"/>'),
    upload: P('<path d="M12 16V4"/><path d="M7 9l5-5 5 5"/><path d="M4 20h16"/>'),
    trash: P('<path d="M4 7h16"/><path d="M10 11v6M14 11v6"/><path d="M6 7l1 13h10l1-13"/><path d="M9 7V4h6v3"/>'),
    palette: P('<path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.6-.9 1.2-1.8-.5-1.1.2-2.2 1.4-2.2H17a4 4 0 0 0 4-4c0-5-4-10-9-10z"/><circle cx="7.5" cy="11" r="1.2"/><circle cx="10.5" cy="7" r="1.2"/><circle cx="15" cy="7.5" r="1.2"/>'),
    network: P('<rect x="9" y="3" width="6" height="5" rx="1"/><rect x="3" y="16" width="6" height="5" rx="1"/><rect x="15" y="16" width="6" height="5" rx="1"/><path d="M12 8v4M6 16v-4h12v4"/>'),
  };
  const icon = (name) => `<span class="icon">${ICONS[name] || ''}</span>`;
  function paintIcons(root) {
    root.querySelectorAll('[data-icon]').forEach((el) => {
      el.innerHTML = ICONS[el.getAttribute('data-icon')] || '';
    });
  }

  // ---------- Helpers ----------
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const hhmm = (d) => String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
  const store = {
    get(k, d) { try { const v = localStorage.getItem(k); return v == null ? d : v; } catch { return d; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode */ } },
  };

  const ZOOMS = ['80%', '100%', '120%', '145%', '170%', '200%'];
  const BASE_FONT = 20;

  // ---------- State ----------
  const S = {
    active: [],
    done: [],
    settings: null,
    status: null,
    clockOffset: 0,
    seen: null,
    rawOpen: new Set(),
    snackId: null,
    connected: false,
  };

  const app = $('app');
  const rail = $('rail');
  paintIcons(document);

  // ---------- Zoom ----------
  let zi = -1;
  function applyZoom() {
    const z = ZOOMS[zi];
    document.documentElement.style.setProperty('--ticket-font', (BASE_FONT * parseFloat(z) / 100) + 'px');
    $('zoom-label').textContent = z;
    $('zoom-out').disabled = zi === 0;
    $('zoom-in').disabled = zi === ZOOMS.length - 1;
    requestAnimationFrame(measure);
  }
  function setZoom(i) {
    zi = Math.max(0, Math.min(ZOOMS.length - 1, i));
    store.set('kds.zoom', ZOOMS[zi]);
    applyZoom();
  }
  $('zoom-out').addEventListener('click', () => setZoom(zi - 1));
  $('zoom-in').addEventListener('click', () => setZoom(zi + 1));

  // ---------- Layout ----------
  const portraitMq = window.matchMedia('(orientation: portrait)');
  function isPortrait() {
    const l = S.settings ? S.settings.layout : 'auto';
    if (l === 'portrait') return true;
    if (l === 'landscape') return false;
    return portraitMq.matches;
  }
  function applyLayout() {
    const p = isPortrait();
    app.classList.toggle('portrait', p);
    $('prev-icon').innerHTML = ICONS[p ? 'up' : 'left'];
    $('next-icon').innerHTML = ICONS[p ? 'down' : 'right'];
    requestAnimationFrame(measure);
  }
  portraitMq.addEventListener('change', applyLayout);
  window.addEventListener('resize', () => requestAnimationFrame(measure));

  // ---------- Time ----------
  const now = () => new Date(Date.now() + S.clockOffset);
  function minutesSince(iso) {
    return Math.max(0, Math.floor((now() - new Date(iso)) / 60000));
  }
  function toneOf(mins) {
    const s = S.settings || { warnMinutes: 10, lateMinutes: 15 };
    if (mins >= s.lateMinutes) return 'late';
    if (mins >= s.warnMinutes) return 'warn';
    return 'ok';
  }

  // ---------- Ticket rendering ----------
  function headOf(t) {
    if (t.isMessage) return { label: 'Besked', value: '', title: 'Besked' };
    if (t.table) return { label: 'Bord', value: t.table, title: 'Bord ' + t.table };
    if (t.takeaway) return { label: t.takeaway, value: '', title: t.takeaway };
    return { label: 'Bon', value: t.orderNo || t.seq, title: 'Bon ' + (t.orderNo || t.seq) };
  }

  function metaOf(t) {
    const parts = ['Bon ' + (t.orderNo || t.seq)];
    if (t.guests) parts.push(t.guests + ' pers.');
    if (t.waiter) parts.push(t.waiter);
    parts.push(t.time || hhmm(new Date(t.receivedAt)));
    return parts.join(' · ');
  }

  function rawHtml(t) {
    const lines = (t.lines || []).map((l) => {
      const cls = [l.big && 'l-big', l.bold && 'l-bold', l.red && 'l-red', l.inverse && 'l-inv', l.align === 'center' && 'l-center', l.align === 'right' && 'l-right'].filter(Boolean).join(' ');
      return cls ? `<span class="${cls}">${esc(l.text) || ' '}</span>` : esc(l.text);
    });
    return `<pre class="raw">${lines.join('\n')}</pre>`;
  }

  function ticketHtml(t, fresh, expanded) {
    const mins = minutesSince(t.receivedAt);
    const tone = toneOf(mins);
    const head = headOf(t);
    const showRaw = !expanded && (S.settings && S.settings.view === 'original' ? !S.rawOpen.has(t.id) : S.rawOpen.has(t.id));
    const courses = (t.sections || []).filter((s) => s.course);
    const onePill = (t.sections || []).length === 1 && courses.length === 1 ? courses[0].course : (t.table && t.takeaway ? t.takeaway : '');
    const cls = ['ticket', tone === 'late' && 'late', t.isMessage && 'is-message', fresh && 'fresh'].filter(Boolean).join(' ');

    let body = '';
    if (showRaw) {
      body += rawHtml(t);
    } else {
      if (t.allergens && t.allergens.length) {
        body += `<div class="allergy" role="note"><div class="allergy-head">${icon('warning')}Allergi</div>` +
          t.allergens.map((a) => `<div class="allergy-line">${esc(a)}</div>`).join('') + '</div>';
      }
      if (t.isMessage) {
        body += `<div class="message">${icon('megaphone')}<span>${esc(t.message)}</span></div>`;
      }
      const showCourse = (t.sections || []).length > 1;
      for (const s of t.sections || []) {
        if (showCourse && s.course) body += `<div class="course">${esc(s.course)}</div>`;
        for (const it of s.items) {
          body += `<div class="item"><div class="item-line"><span class="qty">${esc(it.qty)} ×</span><span class="name">${esc(it.name)}</span>` +
            (it.allergy ? `<span class="icon" role="img" aria-label="Allergi">${ICONS.warning}</span>` : '') + '</div>' +
            it.mods.map((m) => `<div class="mod${m.allergy ? ' allergy-mod' : ''}">${esc(m.text)}</div>`).join('') + '</div>';
        }
      }
      for (const n of t.notes || []) {
        body += `<div class="note" role="note">${icon('note')}<span><b>Note:</b> ${esc(n)}</span></div>`;
      }
      for (const x of t.extra || []) body += `<div class="extra">${esc(x)}</div>`;
    }

    if (expanded) {
      // Wide view: the ticket and the original printout side by side, plus details.
      const received = new Date(t.receivedAt);
      const details = [
        ['Modtaget', received.toLocaleDateString('da-DK') + ' kl. ' + hhmm(received)],
        ['Bon', t.orderNo || t.seq],
        t.guests ? ['Gæster', t.guests] : null,
        t.waiter ? ['Tjener', t.waiter] : null,
        ['Fra', t.from === 'test' ? 'Testbon' : t.from || 'ukendt'],
      ].filter(Boolean);
      body = `<div class="wide-cols"><div class="wide-main">${body}</div><aside class="wide-side">
          <div class="field-label">Original bon</div>${rawHtml(t)}
          <dl class="details">${details.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('')}</dl>
        </aside></div>`;
    }
    const printer = S.settings && S.settings.printerEnabled;
    const footer = expanded
      ? `<div class="wide-actions">
          <button class="btn-done" type="button" data-done="${esc(t.id)}">${icon('check')}${t.isMessage ? 'Læst' : 'Færdig'}</button>
          ${printer ? `<button class="btn-print" type="button" data-print="${esc(t.id)}">${icon('print')}Print</button>` : ''}
        </div>
        <p class="wide-hint">Tryk på bonnen igen for at gøre den lille</p>`
      : `<button class="btn-done" type="button" data-done="${esc(t.id)}">${icon('check')}${t.isMessage ? 'Læst' : 'Færdig'}</button>`;

    return `<article class="${cls}${expanded ? ' expanded' : ''}" data-id="${esc(t.id)}" aria-label="${esc(head.title + ', ' + mins + ' min')}">
      <div class="t-head">
        <div class="t-title"><span class="t-label">${esc(head.label)}</span><span class="t-num">${esc(head.value)}</span></div>
        <span class="t-age tone-${tone}" data-age="${esc(t.receivedAt)}">${icon('clock')}<span>${mins} min</span></span>
      </div>
      <div class="t-meta">
        <span class="t-meta-text">${esc(metaOf(t))}</span>
        <span class="t-meta-right">${onePill ? `<span class="pill">${esc(onePill)}</span>` : ''}
          ${expanded ? '' : `<button class="btn-raw" type="button" data-raw="${esc(t.id)}" aria-pressed="${showRaw}" aria-label="Vis original bon">${ICONS.receipt}</button>`}</span>
      </div>
      <div class="t-body">${body}</div>
      ${footer}
    </article>`;
  }

  let lastIds = new Set();
  function render() {
    const fresh = new Set();
    if (S.seen) for (const t of S.active) if (!S.seen.has(t.id)) fresh.add(t.id);

    const keepLeft = rail.scrollLeft;
    const keepTop = rail.scrollTop;
    rail.innerHTML = S.active.map((t) => ticketHtml(t, fresh.has(t.id) && !lastIds.has(t.id))).join('');
    rail.scrollLeft = keepLeft;
    rail.scrollTop = keepTop;
    lastIds = new Set(S.active.map((t) => t.id));
    $('empty').hidden = S.active.length > 0;

    if (fresh.size && S.settings && S.settings.sound) chime();
    S.seen = new Set([...(S.seen || []), ...S.active.map((t) => t.id)]);

    renderCounts();
    renderDone();
    renderStatus();
    requestAnimationFrame(measure);
  }

  function renderCounts() {
    const n = S.active.length;
    $('waiting-count').textContent = n;
    $('waiting-label').textContent = n === 1 ? 'bon venter' : 'bonner venter';
    let dishes = 0;
    let oldest = -1;
    for (const t of S.active) {
      for (const s of t.sections || []) for (const it of s.items) dishes += it.qty;
      if (!t.isMessage) oldest = Math.max(oldest, minutesSince(t.receivedAt));
    }
    $('dish-count').textContent = dishes;
    const chip = $('oldest');
    chip.hidden = oldest < 0;
    chip.className = 'chip age tone-' + toneOf(oldest);
    $('oldest-text').textContent = 'Ældste ' + oldest + ' min';
    $('done-count').textContent = S.done.length;
  }

  function tickAges() {
    document.querySelectorAll('[data-age]').forEach((el) => {
      const mins = minutesSince(el.getAttribute('data-age'));
      const tone = toneOf(mins);
      el.className = 't-age tone-' + tone;
      el.lastElementChild.textContent = mins + ' min';
      el.closest('.ticket').classList.toggle('late', tone === 'late');
    });
    renderCounts();
    $('clock').textContent = hhmm(now());
  }
  setInterval(tickAges, 15000);
  setInterval(() => { $('clock').textContent = hhmm(now()); }, 1000);

  // ---------- Paging ----------
  function measure() {
    const box = rail.getBoundingClientRect();
    const cards = rail.querySelectorAll('.ticket');
    let first = 0;
    let last = 0;
    cards.forEach((c, i) => {
      const r = c.getBoundingClientRect();
      const w = Math.min(r.right, box.right) - Math.max(r.left, box.left);
      const h = Math.min(r.bottom, box.bottom) - Math.max(r.top, box.top);
      if (w > r.width * 0.6 && h > Math.min(r.height, box.height) * 0.5) {
        if (!first) first = i + 1;
        last = i + 1;
      }
    });
    const n = cards.length;
    if (!first && n) { first = 1; last = 1; }
    $('range-label').textContent = n ? `Viser ${first}–${last} af ${n}` : 'Ingen bonner';
    const more = n - last;
    $('more-label').textContent = n ? ' · ' + (more > 0 ? more + (isPortrait() ? ' flere længere nede' : ' flere til højre') : 'alle vises') : '';
    $('dots').innerHTML = S.active.map((t, i) => {
      const on = i + 1 >= first && i + 1 <= last;
      const late = toneOf(minutesSince(t.receivedAt)) === 'late';
      return `<span class="${on ? 'on' : ''}${late ? ' late' : ''}"></span>`;
    }).join('');
    $('prev').disabled = !n || first <= 1;
    $('next').disabled = !n || last >= n;
  }
  rail.addEventListener('scroll', () => requestAnimationFrame(measure), { passive: true });

  function page(dir) {
    if (isPortrait()) {
      rail.scrollBy({ top: dir * rail.clientHeight * 0.85, behavior: 'smooth' });
      return;
    }
    const card = rail.querySelector('.ticket');
    if (!card) return;
    const gap = parseFloat(getComputedStyle(rail).columnGap) || 12;
    const step = card.getBoundingClientRect().width + gap;
    const per = Math.max(1, Math.floor((rail.clientWidth - 16) / step));
    rail.scrollBy({ left: dir * per * step, behavior: 'smooth' });
  }
  $('prev').addEventListener('click', () => page(-1));
  $('next').addEventListener('click', () => page(1));

  // ---------- Done / recall ----------
  async function post(url) {
    const r = await fetch(url, { method: 'POST' });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  }

  let snackTimer = null;
  function showSnack(t) {
    S.snackId = t.id;
    $('snack-text').textContent = headOf(t).title + ' · bon ' + (t.orderNo || t.seq) + (t.isMessage ? ' er læst' : ' er færdig');
    $('snack').hidden = false;
    clearTimeout(snackTimer);
    snackTimer = setTimeout(() => { $('snack').hidden = true; S.snackId = null; }, 8000);
  }

  rail.addEventListener('click', async (e) => {
    const done = e.target.closest('[data-done]');
    if (done) {
      const id = done.getAttribute('data-done');
      const t = S.active.find((x) => x.id === id);
      const card = done.closest('.ticket');
      card.style.opacity = '0.4';
      try {
        await post('/api/tickets/' + encodeURIComponent(id) + '/done');
        if (t) showSnack(t);
      } catch {
        card.style.opacity = '';
        flash('Kunne ikke afslutte bonnen. Prøv igen.');
      }
      return;
    }
    const raw = e.target.closest('[data-raw]');
    if (raw) {
      const id = raw.getAttribute('data-raw');
      if (S.rawOpen.has(id)) S.rawOpen.delete(id);
      else S.rawOpen.add(id);
      render();
      return;
    }
    // A tap anywhere else on a ticket opens it large.
    const card = e.target.closest('.ticket');
    if (card && !e.target.closest('button, a, input')) openFocus(card.getAttribute('data-id'));
  });

  // ---------- Enlarged ticket ----------
  function openFocus(id) {
    S.focusId = id;
    renderFocus();
  }
  function closeFocus() {
    S.focusId = null;
    $('focus').hidden = true;
  }
  function renderFocus() {
    const t = S.focusId && S.active.find((x) => x.id === S.focusId);
    if (!t) return closeFocus();
    $('focus-card').innerHTML = ticketHtml(t, false, true);
    $('focus').hidden = false;
  }
  $('focus').addEventListener('click', async (e) => {
    const done = e.target.closest('[data-done]');
    if (done) {
      const t = S.active.find((x) => x.id === done.getAttribute('data-done'));
      closeFocus();
      try {
        await post('/api/tickets/' + encodeURIComponent(done.getAttribute('data-done')) + '/done');
        if (t) showSnack(t);
      } catch {
        flash('Kunne ikke afslutte bonnen. Prøv igen.');
      }
      return;
    }
    const pr = e.target.closest('[data-print]');
    if (pr) return printTicket(pr.getAttribute('data-print'), pr);
    // Any other tap, on the ticket or beside it, makes it small again.
    closeFocus();
  });

  async function printTicket(id, btn) {
    const t = S.active.find((x) => x.id === id) || S.done.find((x) => x.id === id);
    if (btn) btn.disabled = true;
    try {
      const r = await fetch('/api/tickets/' + encodeURIComponent(id) + '/print', { method: 'POST' });
      const j = await r.json();
      flash(j.ok ? `${t ? headOf(t).title + ' · ' : ''}sendt til printeren` : j.error || 'Kunne ikke printe');
    } catch {
      flash('Kunne ikke printe. Tjek forbindelsen.');
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function restore(id) {
    try {
      await post('/api/tickets/' + encodeURIComponent(id) + '/restore');
    } catch {
      flash('Kunne ikke hente bonnen tilbage. Prøv igen.');
    }
  }

  $('snack-undo').addEventListener('click', () => {
    if (S.snackId) restore(S.snackId);
    $('snack').hidden = true;
    S.snackId = null;
  });

  function renderDone() {
    $('recall-hint').textContent = 'Hent en bon tilbage, hvis den blev fjernet ved en fejl. Listen ryddes ved ny arbejdsdag kl. ' + ((S.settings && S.settings.dayStart) || '06:00') + '.';
    const list = $('done-list');
    if (!S.done.length) {
      list.innerHTML = '<p class="drawer-empty">Ingen afsluttede bonner endnu.</p>';
      return;
    }
    list.innerHTML = S.done.map((t) => {
      const head = headOf(t);
      const count = (t.sections || []).reduce((a, s) => a + s.items.reduce((b, it) => b + it.qty, 0), 0);
      const summary = t.isMessage ? t.message : (t.sections || []).flatMap((s) => s.items.map((it) => it.qty + ' × ' + it.name)).join(', ');
      const sub = 'Bon ' + (t.orderNo || t.seq) + (count ? ' · ' + count + ' retter' : '') + ' · færdig ' + (t.doneAt ? hhmm(new Date(t.doneAt)) : '');
      return `<div class="done-row"><div class="done-text"><span class="done-title">${esc(head.title)}</span><span class="done-sub">${esc(sub)}</span><span class="done-sum">${esc(summary)}</span></div>
        <button class="btn-accent" type="button" data-restore="${esc(t.id)}">${icon('undo')}Hent tilbage</button></div>`;
    }).join('');
  }
  $('done-list').addEventListener('click', (e) => {
    const b = e.target.closest('[data-restore]');
    if (b) restore(b.getAttribute('data-restore'));
  });

  $('open-recall').addEventListener('click', () => { $('recall').hidden = false; });
  document.addEventListener('click', (e) => {
    const c = e.target.closest('[data-close]');
    if (!c) return;
    $(c.getAttribute('data-close')).hidden = true;
    if (c.getAttribute('data-close') === 'settings' && S.settings) applyTheme(S.settings);
  });

  // ---------- Status ----------
  function renderStatus() {
    const s = S.settings;
    const st = S.status;
    if (s) $('printer-name').textContent = s.printerName || 'Køkken';
    const conn = $('conn');
    let ok = true;
    let text;
    if (!S.connected) { ok = false; text = 'Ingen forbindelse til serveren'; }
    else if (st && st.error) { ok = false; text = 'Printer stoppet: ' + st.error; }
    else if (st && st.listening) {
      const ip = st.address === '0.0.0.0' && st.ips && st.ips[0] ? st.ips[0].address : st.address;
      text = `Printer ${ip}:${st.port} · klar`;
    } else text = 'Printer starter…';
    conn.className = 'conn ' + (ok ? 'ok' : 'bad');
    conn.firstElementChild.innerHTML = ICONS[ok ? 'check' : 'warning'];
    $('conn-text').textContent = text;
  }

  function flash(msg) {
    $('snack-text').textContent = msg;
    $('snack-undo').hidden = true;
    $('snack').hidden = false;
    clearTimeout(snackTimer);
    snackTimer = setTimeout(() => { $('snack').hidden = true; $('snack-undo').hidden = false; }, 5000);
  }

  // ---------- Sound ----------
  let audio = null;
  function ensureAudio() {
    if (!audio) {
      try { audio = new (window.AudioContext || window.webkitAudioContext)(); } catch { return null; }
    }
    if (audio.state === 'suspended') audio.resume().catch(() => {});
    return audio;
  }
  function chime() {
    const ctx = ensureAudio();
    if (!ctx) return;
    if (ctx.state !== 'running') { $('sound-unlock').hidden = false; return; }
    const t0 = ctx.currentTime;
    [[880, 0], [1320, 0.18]].forEach(([f, dt]) => {
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, t0 + dt);
      g.gain.exponentialRampToValueAtTime(0.5, t0 + dt + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dt + 0.35);
      o.connect(g).connect(ctx.destination);
      o.start(t0 + dt);
      o.stop(t0 + dt + 0.4);
    });
  }
  document.addEventListener('pointerdown', () => {
    const ctx = ensureAudio();
    if (ctx && ctx.state === 'running') $('sound-unlock').hidden = true;
  });
  $('sound-unlock').addEventListener('click', () => {
    ensureAudio();
    setTimeout(() => { if (audio && audio.state === 'running') { $('sound-unlock').hidden = true; chime(); } }, 100);
  });

  // ---------- Keep the screen on ----------
  async function wakeLock() {
    try { if ('wakeLock' in navigator) await navigator.wakeLock.request('screen'); } catch { /* not allowed */ }
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden) wakeLock(); });
  wakeLock();

  // ---------- Settings ----------
  const form = $('settings-form');
  function fillSettings() {
    const s = S.settings;
    if (!s) return;
    for (const el of form.elements) {
      if (!el.name || !(el.name in s)) continue;
      const v = s[el.name];
      if (el.type === 'checkbox') el.checked = !!v;
      else if (Array.isArray(v)) el.value = v.join(', ');
      else el.value = v;
    }
    renderSettingsStatus();
  }
  function renderSettingsStatus() {
    const st = S.status || {};
    const chip = $('listen-chip');
    chip.className = 'chip ' + (st.listening ? 'tone-ok' : 'tone-late');
    chip.innerHTML = icon(st.listening ? 'check' : 'warning') + esc(st.listening ? `Lytter på ${st.address}:${st.port}` : (st.error || 'Lytter ikke'));
    const ips = st.ips || [];
    $('ip-list').innerHTML = ips.length
      ? ips.map((i) => `<span class="ip">${esc(i.address)}<small>${esc(i.iface)}</small></span>`).join('')
      : '<span class="muted">Ingen netværksforbindelse fundet</span>';
    $('last-job').textContent = st.lastJobAt ? 'Sidste bon modtaget kl. ' + hhmm(new Date(st.lastJobAt)) + ' · ' + st.jobs + ' siden start' : 'Ingen bonner modtaget siden start.';
  }
  $('open-settings').addEventListener('click', () => {
    fillSettings();
    S.colors = pickColors(S.settings);
    S.logoChoice = S.settings.logo || 'ctpos';
    renderPrintStatus();
    logoDraft = {};
    renderColors();
    renderLogoSettings();
    $('settings-msg').textContent = '';
    $('settings').hidden = false;
  });

  // ---------- Colours ----------
  const PAL = window.KDSPalette;
  const COLOR_KEYS = ['themeMode', 'palette', 'customAccent', 'customNeutralHue', 'customNeutralTint'];
  const SWATCHES = ['#ED1C24', '#C67139', '#E39A0E', '#16915A', '#0F8B8D', '#2463D6', '#5B4BDB', '#B0327A', '#7A5230', '#4A5560'];
  const pickColors = (s) => Object.fromEntries(COLOR_KEYS.map((k) => [k, s[k]]));

  /** Paints the page in a palette and swaps the logo to the version that reads on it. */
  function applyTheme(colors) {
    const p = PAL.apply(colors);
    const venue = venueLogoUrl(p.dark);
    const logo = venue || (p.dark ? 'ctpos_reversed.png' : 'ctpos_color.png');
    document.querySelectorAll('.brand-logo, .brand-swap').forEach((img) => {
      if (img.getAttribute('src') !== logo) img.setAttribute('src', logo);
      img.alt = venue ? 'Logo' : 'CTpos';
      img.classList.toggle('venue-logo', !!venue);
    });
    return p;
  }

  /** The venue's own logo for dark or light mode (or the other one if only one exists), else null. */
  function venueLogoUrl(dark) {
    const l = S.logos;
    if (!S.settings || S.settings.logo !== 'custom' || !l) return null;
    const mode = dark ? (l.dark ? 'dark' : l.light ? 'light' : null) : (l.light ? 'light' : l.dark ? 'dark' : null);
    return mode ? `/api/logo/${mode}?v=${l.version}` : null;
  }

  // ---------- Logo settings ----------
  // Picked images wait here until Gem: { dark: File | 'remove' | undefined, light: … }.
  let logoDraft = {};
  let logoTarget = 'dark';
  const logoPreviewUrls = {};

  function draftLogoUrl(mode) {
    const v = logoDraft[mode];
    if (v === 'remove') return null;
    if (v instanceof File) {
      if (!logoPreviewUrls[mode] || logoPreviewUrls[mode].file !== v) {
        if (logoPreviewUrls[mode]) URL.revokeObjectURL(logoPreviewUrls[mode].url);
        logoPreviewUrls[mode] = { file: v, url: URL.createObjectURL(v) };
      }
      return logoPreviewUrls[mode].url;
    }
    return S.logos && S.logos[mode] ? `/api/logo/${mode}?v=${S.logos.version}` : null;
  }

  function renderLogoSettings(msg) {
    const custom = S.logoChoice === 'custom';
    const seed = PAL.seedOf(S.colors || S.settings);
    const slot = (mode, title, hint) => {
      const own = draftLogoUrl(mode);
      const other = draftLogoUrl(mode === 'dark' ? 'light' : 'dark');
      const shown = own || other;
      const bar = hex(PAL.compute(seed, mode === 'dark').paperBar);
      const muted = hex(PAL.compute(seed, mode === 'dark').muted);
      return `<div class="logo-slot">
        <div><h3>${title}</h3><div class="muted small">${own || !other ? hint : 'Bruger det andet logo'}</div></div>
        <div class="logo-box" style="background:${bar}">${shown ? `<img src="${esc(shown)}" alt="Logo til ${mode === 'dark' ? 'mørk' : 'lys'} visning">` : `<span style="color:${muted}">Intet billede valgt</span>`}</div>
        <div class="logo-actions">
          <button type="button" class="btn-outline" data-logo-pick="${mode}">${icon('upload')}${own ? 'Skift billede' : 'Vælg billede'}</button>
          ${own ? `<button type="button" class="btn-outline danger" data-logo-remove="${mode}">${icon('trash')}Fjern</button>` : ''}
        </div>
      </div>`;
    };
    $('logo-settings').innerHTML = `
      <div class="modes" role="group" aria-label="Logo">
        <button type="button" data-logo-choice="ctpos" aria-pressed="${!custom}">CTpos</button>
        <button type="button" data-logo-choice="custom" aria-pressed="${custom}">Eget logo</button>
      </div>
      <p class="muted small" style="margin:6px 0 0">Appens ikon og fanebladets ikon er altid CTpos.</p>
      ${custom ? `<div class="logo-slots">${slot('dark', 'Til mørk visning', 'Lyst logo, fx hvid tekst')}${slot('light', 'Til lys visning', 'Mørkt logo, fx sort tekst')}</div>
        <p class="muted small" style="margin:10px 0 0">Har du kun ét logo, bruges det i begge visninger. PNG med gennemsigtig baggrund er bedst. Højst 2 MB.</p>` : ''}
      ${msg ? `<p class="small" style="margin:10px 0 0;color:var(--bad);font-weight:600">${esc(msg)}</p>` : ''}`;
  }

  $('logo-settings').addEventListener('click', (e) => {
    const c = e.target.closest('[data-logo-choice]');
    if (c) { S.logoChoice = c.dataset.logoChoice; return renderLogoSettings(); }
    const pick = e.target.closest('[data-logo-pick]');
    if (pick) { logoTarget = pick.dataset.logoPick; $('logo-file').value = ''; return $('logo-file').click(); }
    const rm = e.target.closest('[data-logo-remove]');
    if (rm) { logoDraft[rm.dataset.logoRemove] = 'remove'; renderLogoSettings(); }
  });
  $('logo-file').addEventListener('change', () => {
    const f = $('logo-file').files[0];
    if (!f) return;
    if (!/^image\/(png|jpeg|webp|gif)$/.test(f.type)) return renderLogoSettings('Vælg en PNG, JPG, WebP eller GIF.');
    if (f.size > 2 * 1024 * 1024) return renderLogoSettings('Billedet er for stort. Højst 2 MB.');
    logoDraft[logoTarget] = f;
    S.logoChoice = 'custom';
    renderLogoSettings();
  });

  async function saveLogos() {
    for (const mode of ['dark', 'light']) {
      const v = logoDraft[mode];
      if (v instanceof File) {
        const r = await fetch('/api/logo/' + mode, { method: 'PUT', headers: { 'Content-Type': v.type }, body: v });
        const j = await r.json();
        if (!r.ok) throw new Error(j.error || 'Logoet kunne ikke gemmes');
        S.logos = j;
      } else if (v === 'remove') {
        S.logos = await (await fetch('/api/logo/' + mode, { method: 'DELETE' })).json();
      }
    }
    logoDraft = {};
  }
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', () => applyTheme($('settings').hidden ? S.settings : S.colors));

  const hex = (rgb) => PAL.rgbToHex(rgb);
  function strip(p) {
    return `<div class="pal-strip" style="background:${hex(p.paper)}">` +
      [p.card, p.accent, p.ok, p.warn, p.bad].map((c) => `<span style="background:${hex(c)};border:1px solid ${hex(p.outlineVariant)}"></span>`).join('') + '</div>';
  }
  function preview(p, title) {
    const c = (k) => hex(p[k]);
    const checks = p.checks.map((k) => `<div><span>${k.ratio >= 4.5 ? '✓' : '!'} ${esc(k.label)}</span><span>${k.ratio.toFixed(1).replace('.', ',')}:1</span></div>`).join('');
    return `<div class="pv" style="background:${c('paper')};color:${c('ink')}">
      <div class="pv-title" style="color:${c('muted')}">${esc(title)}</div>
      <div class="pv-ticket" style="background:${c('card')};border:1px solid ${c('outlineVariant')}">
        <div class="pv-head" style="background:${c('paperBar')}"><span style="color:${c('muted')}">Bord</span><span class="num" style="color:${c('strong')}">12</span>
          <span class="pv-chip" style="color:${c('warn')}">12 min</span><span class="pv-chip" style="background:${c('bad')};border-color:${c('bad')};color:${c('onBad')}">18 min</span></div>
        <div class="pv-body">
          <div style="font-size:13px;color:${c('muted')}">Bon 1041 · 4 pers. · Mette</div>
          <div class="pv-box" style="background:${c('badGround')};border:2px solid ${c('bad')};color:${c('bad')}">Allergi: gluten</div>
          <div class="pv-item" style="color:${c('ink')}">2 ×  Wienerschnitzel</div>
          <div class="pv-mod" style="color:${c('primary')}">Uden kapers</div>
          <div class="pv-box" style="background:${c('primaryContainer')};color:${c('onPrimaryContainer')};font-weight:600">Note: børneretten først</div>
          <div class="pv-btn" style="background:${c('accent')};color:${c('onAccent')}">Færdig</div>
        </div>
      </div>
      <div class="pv-checks" style="color:${c('ink')}">${checks}</div>
    </div>`;
  }

  let renderColors = function () {
    const d = S.colors;
    const seed = PAL.seedOf(d);
    const all = [...PAL.PRESETS, PAL.seedOf({ ...d, palette: 'custom' })];
    const mode = (v, label) => `<button type="button" data-mode="${v}" aria-pressed="${d.themeMode === v}">${label}</button>`;
    const accentHsl = PAL.rgbToHsl(PAL.hexToRgb(d.customAccent) || [237, 28, 36]);
    const range = (name, label, min, max, step, value, text) =>
      `<label class="range-row"><span>${label}</span><input type="range" data-range="${name}" min="${min}" max="${max}" step="${step}" value="${value}"><output>${text}</output></label>`;

    $('colors').innerHTML = `
      <div class="field-label">Visning</div>
      <div class="modes" role="group" aria-label="Visning">${mode('dark', 'Mørk')}${mode('light', 'Lys')}${mode('auto', 'Automatisk')}</div>
      <p class="muted small" style="margin:6px 0 18px">Automatisk følger skærmens egen indstilling for lys og mørk.</p>
      <div class="field-label">Palet</div>
      <div class="palettes">${all.map((p) => `<button type="button" class="pal" data-palette="${p.id}" aria-pressed="${d.palette === p.id}">
          ${strip(PAL.compute(p, true))}${strip(PAL.compute(p, false))}
          <span class="pal-text"><span class="pal-name">${esc(p.name)}</span><span class="pal-desc">${esc(p.description)}</span></span></button>`).join('')}</div>
      ${d.palette === 'custom' ? `<div class="custom" style="margin-top:18px">
          <h3>Egen accentfarve</h3>
          <div class="swatches">${SWATCHES.map((h) => `<button type="button" data-swatch="${h}" aria-label="${h}" aria-pressed="${h.toUpperCase() === String(d.customAccent).toUpperCase()}" style="background:${h}"></button>`).join('')}
            <input type="color" data-accent value="${esc(String(d.customAccent).toLowerCase())}" aria-label="Vælg farve"></div>
          ${range('hue', 'Farvetone', 0, 360, 1, Math.round(accentHsl.h), Math.round(accentHsl.h) + '°')}
          ${range('sat', 'Mætning', 0, 100, 1, Math.round(accentHsl.s * 100), Math.round(accentHsl.s * 100) + ' %')}
          ${range('light', 'Lyshed', 0, 100, 1, Math.round(accentHsl.l * 100), Math.round(accentHsl.l * 100) + ' %')}
          <h3>Baggrundens tone</h3>
          ${range('nhue', 'Farvetone', 0, 360, 1, Math.round(d.customNeutralHue), Math.round(d.customNeutralHue) + '°')}
          ${range('ntint', 'Styrke', 0, 40, 1, Math.round(d.customNeutralTint * 100), d.customNeutralTint ? Math.round(d.customNeutralTint * 100) + ' %' : 'Grå')}
          <p class="muted small">Knapper, tekst, allergier og statusfarver beregnes automatisk ud fra dine valg til både mørk og lys visning, og justeres så de altid kan læses (mindst 4,5:1).</p>
        </div>` : ''}
      <div class="field-label" style="margin-top:18px">Forhåndsvisning</div>
      <div class="previews">${preview(PAL.compute(seed, true), 'Mørk')}${preview(PAL.compute(seed, false), 'Lys')}</div>`;
    applyTheme(d);
  };

  function setColors(patch) {
    Object.assign(S.colors, patch);
    renderColors();
    renderLogoSettings();
  }
  $('colors').addEventListener('click', (e) => {
    const m = e.target.closest('[data-mode]');
    if (m) return setColors({ themeMode: m.dataset.mode });
    const p = e.target.closest('[data-palette]');
    if (p) return setColors({ palette: p.dataset.palette });
    const sw = e.target.closest('[data-swatch]');
    if (sw) setColors({ customAccent: sw.dataset.swatch });
  });
  $('colors').addEventListener('input', (e) => {
    const t = e.target;
    if (t.matches('[data-accent]')) return setColors({ customAccent: t.value.toUpperCase() });
    const r = t.dataset.range;
    if (!r) return;
    const v = Number(t.value);
    if (r === 'nhue') return setColors({ customNeutralHue: v });
    if (r === 'ntint') return setColors({ customNeutralTint: v / 100 });
    const h = PAL.rgbToHsl(PAL.hexToRgb(S.colors.customAccent) || [237, 28, 36]);
    if (r === 'hue') h.h = v;
    if (r === 'sat') h.s = v / 100;
    if (r === 'light') h.l = v / 100;
    setColors({ customAccent: PAL.rgbToHex(PAL.hslToRgb(h)) });
  });
  // Re-rendering the sliders mid-drag would drop the pointer, so restore focus to the same one.
  const colorsEl = $('colors');
  const origRender = renderColors;
  renderColors = function () {
    const active = document.activeElement && colorsEl.contains(document.activeElement) ? document.activeElement.dataset.range : null;
    origRender();
    if (active) { const el = colorsEl.querySelector(`[data-range="${active}"]`); if (el) el.focus(); }
  };
  $('btn-save').addEventListener('click', async () => {
    const body = {};
    for (const el of form.elements) {
      if (!el.name) continue;
      body[el.name] = el.type === 'checkbox' ? el.checked : el.value;
    }
    Object.assign(body, S.colors, { logo: S.logoChoice });
    try {
      try {
        await saveLogos();
      } catch (err) {
        renderLogoSettings(err.message);
        $('settings-msg').textContent = 'Logoet blev ikke gemt';
        return;
      }
      const r = await fetch('/api/settings', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const j = await r.json();
      S.settings = j.settings;
      applyTheme(S.colors);
      renderLogoSettings();
      if (body.zoom) setZoom(ZOOMS.indexOf(body.zoom));
      applyLayout();
      render();
      $('settings-msg').textContent = j.restartNeeded ? 'Gemt. Genstart programmet for at skifte webport.' : 'Gemt';
    } catch {
      $('settings-msg').textContent = 'Kunne ikke gemme. Tjek forbindelsen.';
    }
  });
  $('btn-print-test').addEventListener('click', async () => {
    const btn = $('btn-print-test');
    btn.disabled = true;
    // Test with the address typed in, even before Gem: save the printer fields first.
    const body = {};
    for (const name of ['printerEnabled', 'printerHost', 'printerPort', 'autoPrint', 'printerPaper']) {
      const el = form.elements[name];
      body[name] = el.type === 'checkbox' ? el.checked : el.value;
    }
    body.printerEnabled = true;
    form.elements.printerEnabled.checked = true;
    try {
      await fetch('/api/settings', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const r = await fetch('/api/printer/test', { method: 'POST' });
      S.lastPrint = await r.json();
      S.printerInfo = (await fetch('/api/state').then((x) => x.json())).printerInfo;
    } catch {
      S.lastPrint = { ok: false, error: 'Kunne ikke nå skærmens server' };
    }
    btn.disabled = false;
    renderPrintStatus();
  });
  function renderPrintStatus() {
    const i = S.printerInfo;
    const name = i && [i.maker, i.model].filter(Boolean).join(' ');
    const how = !i ? '' : i.source === 'printer' ? 'aflæst fra printeren' : i.source === 'setting' ? 'valgt i opsætningen' : 'printeren oplyste ikke sin model, så den sikre bredde bruges. Vælg papirbredde, hvis bonnen skal bruge hele papiret';
    $('printer-info').textContent = i
      ? `Printer: ${name || 'ukendt model'} · ${i.paper} · ${i.cols} tegn pr. linje (${how}).`
      : 'Printerens model og bredde aflæses ved første udskrift eller testudskrift.';
    const p = S.lastPrint;
    const el = $('print-status');
    if (!p) { el.textContent = 'Ingen udskrifter endnu.'; el.style.color = ''; return; }
    el.textContent = p.ok ? `${p.what} printet kl. ${hhmm(new Date(p.at))}` : `${p.what || 'Udskrift'} fejlede: ${p.error}`;
    el.style.color = p.ok ? 'var(--ok)' : 'var(--bad)';
  }

  $('btn-test').addEventListener('click', async () => {
    ensureAudio();
    try { await post('/api/test'); $('settings-msg').textContent = 'Testbon sendt til skærmen'; } catch { $('settings-msg').textContent = 'Testbon fejlede'; }
  });
  $('btn-clear').addEventListener('click', async () => {
    if (!window.confirm('Fjern alle bonner, også de afsluttede?')) return;
    await fetch('/api/tickets', { method: 'DELETE' });
    $('settings-msg').textContent = 'Alle bonner er fjernet';
  });
  $('btn-fullscreen').addEventListener('click', () => {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen().catch(() => {});
  });

  // ---------- Live connection ----------
  function onState(data) {
    S.clockOffset = new Date(data.serverTime) - Date.now();
    const firstLoad = !S.settings;
    S.settings = data.settings;
    S.logos = data.logos;
    S.status = data.status;
    S.active = data.active;
    S.done = data.done;
    if (S.snackId && !S.done.some((t) => t.id === S.snackId)) { $('snack').hidden = true; S.snackId = null; }
    if (firstLoad) {
      const saved = store.get('kds.zoom', null);
      zi = ZOOMS.indexOf(saved || S.settings.zoom);
      if (zi < 0) zi = 1;
      applyZoom();
      S.seen = new Set(S.active.map((t) => t.id));
    }
    S.lastPrint = data.lastPrint;
    S.printerInfo = data.printerInfo;
    if ($('settings').hidden) applyTheme(S.settings);
    applyLayout();
    render();
    if (S.focusId) renderFocus();
    if (!$('settings').hidden) renderSettingsStatus();
    $('clock').textContent = hhmm(now());
  }

  function connect() {
    const es = new EventSource('/api/events');
    es.addEventListener('state', (e) => {
      S.connected = true;
      onState(JSON.parse(e.data));
    });
    es.onerror = () => {
      S.connected = false;
      renderStatus();
    };
  }
  connect();
})();
