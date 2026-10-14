'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Store, workdayStart } = require('../server/store');

const at = (s) => new Date(s).getTime();

test('the workday starts at the set time, yesterday if that is still ahead', () => {
  assert.strictEqual(workdayStart(at('2026-10-14T07:30'), '06:00').getTime(), at('2026-10-14T06:00'));
  assert.strictEqual(workdayStart(at('2026-10-14T05:59'), '06:00').getTime(), at('2026-10-13T06:00'));
  assert.strictEqual(workdayStart(at('2026-10-14T23:00'), '04:30').getTime(), at('2026-10-14T04:30'));
});

function storeWith(settings, tickets) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kds-'));
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify(settings));
  const s = new Store(dir);
  s.tickets = tickets; // after loading, which already purges by the real clock
  return s;
}

const ticket = (id, status, receivedAt, doneAt = null) => ({ id, seq: 1, status, receivedAt: new Date(receivedAt).toISOString(), doneAt: doneAt && new Date(doneAt).toISOString() });

test('at 06:00 yesterday is cleared: Afsluttede starts at 0 and stale waiting tickets go', () => {
  const s = storeWith({ dayStart: '06:00', keepDoneHours: 0, dayResetActive: true }, [
    ticket('done-yesterday', 'done', '2026-10-13T21:00', '2026-10-13T21:20'),
    ticket('done-after-midnight', 'done', '2026-10-14T01:00', '2026-10-14T01:30'),
    ticket('waiting-from-yesterday', 'active', '2026-10-13T22:40'),
    ticket('done-today', 'done', '2026-10-14T06:30', '2026-10-14T06:45'),
    ticket('waiting-today', 'active', '2026-10-14T06:50'),
  ]);
  s.purge(at('2026-10-14T07:00'));
  assert.deepStrictEqual(s.tickets.map((t) => t.id), ['done-today', 'waiting-today']);
});

test('before the workday start nothing from the night shift is cleared', () => {
  const s = storeWith({ dayStart: '06:00', keepDoneHours: 0, dayResetActive: true }, [
    ticket('done-late-evening', 'done', '2026-10-13T23:00', '2026-10-13T23:30'),
    ticket('waiting-late', 'active', '2026-10-14T01:00'),
  ]);
  s.purge(at('2026-10-14T05:00'));
  assert.strictEqual(s.tickets.length, 2);
});

test('waiting tickets can be kept, and hours still clear finished ones sooner', () => {
  const s = storeWith({ dayStart: '06:00', keepDoneHours: 2, dayResetActive: false }, [
    ticket('waiting-from-yesterday', 'active', '2026-10-13T22:40'),
    ticket('done-3h-ago', 'done', '2026-10-14T08:00', '2026-10-14T09:00'),
    ticket('done-1h-ago', 'done', '2026-10-14T10:30', '2026-10-14T11:00'),
  ]);
  s.purge(at('2026-10-14T12:00'));
  assert.deepStrictEqual(s.tickets.map((t) => t.id), ['waiting-from-yesterday', 'done-1h-ago']);
});
