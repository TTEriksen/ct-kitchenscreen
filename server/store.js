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
  keepDoneHours: 2,
  idleFlushMs: 800,
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

  purge() {
    const keepMs = Math.max(0, Number(this.settings.keepDoneHours) || 0) * 3600 * 1000;
    const now = Date.now();
    const before = this.tickets.length;
    this.tickets = this.tickets.filter((t) => t.status !== 'done' || now - Date.parse(t.doneAt) < keepMs);
    if (this.tickets.length !== before) this.save();
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
    if (next.port < 1 || next.port > 65535) next.port = DEFAULT_SETTINGS.port;
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

module.exports = { Store, DEFAULT_SETTINGS };
