'use strict';

const fs = require('fs');
const path = require('path');
const { DEFAULT_ALLERGEN_WORDS } = require('./parser');

const DEFAULT_SETTINGS = {
  printerName: 'Køkkenprinter 1',
  bindAddress: '0.0.0.0',
  port: 9100,
  webPort: 8080,
  protocol: 'escpos', // 'escpos' | 'star'
  charset: 'auto', // 'auto' | 'utf8' | 'cp865' | 'cp850' | 'cp858' | 'cp437' | 'cp1252'
  zoom: '100%',
  layout: 'auto', // 'auto' | 'landscape' | 'portrait'
  view: 'parsed', // 'parsed' | 'original'
  warnMinutes: 10,
  lateMinutes: 15,
  sound: true,
  keepDoneHours: 0, // 0 = keep finished tickets for the whole workday
  dayStart: '06:00', // a new workday starts here: yesterday's tickets are cleared
  dayResetActive: true, // also clear tickets still waiting from the previous workday
  idleFlushMs: 800,
  themeMode: 'dark', // 'dark' | 'light' | 'auto'
  logo: 'ctpos', // top-bar logo: 'ctpos' | 'custom' (the venue's own; app icon stays CTpos)
  printerEnabled: false, // a physical network printer to print tickets on
  printerHost: '',
  printerPort: 9100,
  autoPrint: false, // print every incoming ticket as well as showing it
  printerPaper: 'auto', // 'auto' (ask the printer) | '80-48' | '80-42' | '58-32'
  palette: 'ctpos', // 'ctpos' | 'brasserie' | 'hav' | 'skov' | 'kontrast' | 'custom'
  customAccent: '#ED1C24',
  customNeutralHue: 0,
  customNeutralTint: 0,
  allergenWords: DEFAULT_ALLERGEN_WORDS,
};

class Store {
  constructor(dir) {
    this.dir = dir;
    fs.mkdirSync(dir, { recursive: true });
    this.ticketsFile = path.join(dir, 'tickets.json');
    this.settingsFile = path.join(dir, 'settings.json');
    this.settings = { ...DEFAULT_SETTINGS, ...readJson(this.settingsFile, {}) };
    const saved = readJson(this.ticketsFile, { seq: 0, tickets: [] });
    this.seq = saved.seq || 0;
    this.tickets = Array.isArray(saved.tickets) ? saved.tickets : [];
    this.listeners = new Set();
    this.saveTimer = null;
    this.purge();
  }

  onChange(fn) {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  emit(kind, payload) {
    for (const fn of this.listeners) fn(kind, payload);
  }

  add(ticket) {
    this.seq += 1;
    const t = {
      id: String(Date.now()) + '-' + this.seq,
      seq: this.seq,
      status: 'active',
      receivedAt: new Date().toISOString(),
      doneAt: null,
      ...ticket,
    };
    this.tickets.push(t);
    this.save();
    this.emit('added', t);
    return t;
  }

  setStatus(id, status) {
    const t = this.tickets.find((x) => x.id === id);
    if (!t) return null;
    t.status = status;
    t.doneAt = status === 'done' ? new Date().toISOString() : null;
    this.save();
    this.emit('changed', t);
    return t;
  }

  clearAll() {
    this.tickets = [];
    this.save();
    this.emit('changed', null);
  }

  snapshot() {
    this.purge();
    const active = this.tickets.filter((t) => t.status === 'active').sort((a, b) => a.seq - b.seq);
    const done = this.tickets
      .filter((t) => t.status === 'done')
      .sort((a, b) => (b.doneAt || '').localeCompare(a.doneAt || ''));
    return { active, done };
  }

  /**
   * Clears what belongs to an earlier workday: finished tickets always, and
   * tickets still waiting from then if dayResetActive is on. Finished tickets
   * can also be cleared sooner, keepDoneHours after they were finished.
   */
  purge(now = Date.now()) {
    const dayStart = workdayStart(now, this.settings.dayStart).getTime();
    const keepMs = Math.max(0, Number(this.settings.keepDoneHours) || 0) * 3600 * 1000;
    const before = this.tickets.length;
    this.tickets = this.tickets.filter((t) => {
      if (t.status === 'done') {
        const done = Date.parse(t.doneAt);
        return done >= dayStart && (!keepMs || now - done < keepMs);
      }
      return !this.settings.dayResetActive || Date.parse(t.receivedAt) >= dayStart;
    });
    if (this.tickets.length !== before) {
      this.save();
      return true;
    }
    return false;
  }

  updateSettings(patch) {
    const next = { ...this.settings };
    for (const key of Object.keys(DEFAULT_SETTINGS)) {
      if (!(key in patch)) continue;
      const def = DEFAULT_SETTINGS[key];
      let v = patch[key];
      if (typeof def === 'number') {
        v = Number(v);
        if (!Number.isFinite(v)) continue;
      } else if (typeof def === 'boolean') {
        v = v === true || v === 'true';
      } else if (Array.isArray(def)) {
        if (typeof v === 'string') v = v.split(/[,\n]/);
        if (!Array.isArray(v)) continue;
        v = v.map((s) => String(s).trim()).filter(Boolean);
      } else {
        v = String(v).trim();
      }
      next[key] = v;
    }
    if (!/^#[0-9a-fA-F]{6}$/.test(next.customAccent)) next.customAccent = DEFAULT_SETTINGS.customAccent;
    if (!['dark', 'light', 'auto'].includes(next.themeMode)) next.themeMode = DEFAULT_SETTINGS.themeMode;
    if (!['ctpos', 'custom'].includes(next.logo)) next.logo = DEFAULT_SETTINGS.logo;
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(next.dayStart)) next.dayStart = DEFAULT_SETTINGS.dayStart;
    next.customNeutralHue = Math.min(360, Math.max(0, next.customNeutralHue));
    next.customNeutralTint = Math.min(0.4, Math.max(0, next.customNeutralTint));
    if (next.port < 1 || next.port > 65535) next.port = DEFAULT_SETTINGS.port;
    if (next.printerPort < 1 || next.printerPort > 65535) next.printerPort = DEFAULT_SETTINGS.printerPort;
    if (!/^[A-Za-z0-9.:-]{0,253}$/.test(next.printerHost)) next.printerHost = '';
    if (!['auto', '80-48', '80-42', '58-32'].includes(next.printerPaper)) next.printerPaper = 'auto';
    if (next.webPort < 1 || next.webPort > 65535) next.webPort = DEFAULT_SETTINGS.webPort;
    const old = this.settings;
    this.settings = next;
    writeJson(this.settingsFile, next);
    this.emit('settings', { old, next });
    return next;
  }

  save() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.flush(), 200);
  }

  flush() {
    clearTimeout(this.saveTimer);
    writeJson(this.ticketsFile, { seq: this.seq, tickets: this.tickets });
  }
}

/** When the current workday began: today at dayStart ("06:00"), or yesterday if that is still ahead. */
function workdayStart(now, dayStart) {
  const [h, m] = String(dayStart || '06:00').split(':').map(Number);
  const d = new Date(now);
  d.setHours(h || 0, m || 0, 0, 0);
  if (d.getTime() > now) d.setDate(d.getDate() - 1);
  return d;
}

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function writeJson(file, data) {
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
  fs.renameSync(tmp, file);
}

module.exports = { Store, DEFAULT_SETTINGS, workdayStart };
