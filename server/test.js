import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, test } from 'node:test';
import { createServer } from './app.js';
import { expandStudio } from './seed.js';
import { statusForWindow } from './validate.js';

const root = mkdtempSync(join(tmpdir(), 'kiln-'));
const dbPath = join(root, 'kiln.sqlite');
let running;

before(async () => {
  running = await createServer({ dbPath, host: '127.0.0.1', port: 0 });
});

after(async () => {
  await running.close();
  rmSync(root, { recursive: true, force: true });
});

function base() {
  return `http://127.0.0.1:${running.port}`;
}

test('iso week and bisque status agree on the morning of 16 Nov 2026', () => {
  const now = new Date(2026, 10, 16, 9, 0, 0, 0);
  const studio = expandStudio(undefined, now);
  const bisque = studio.firings.find((firing) => firing.id.endsWith('skutt-bisque'));
  assert.equal(bisque.id, 'firing-2026-W47-skutt-bisque');
  assert.equal(bisque.status, 'loading');
  const start = new Date(bisque.startsAt);
  assert.equal(start.getFullYear(), 2026);
  assert.equal(start.getMonth(), 10);
  assert.equal(start.getDate(), 16);
  assert.equal(start.getHours(), 8);
  assert.equal(statusForWindow(bisque.startsAt, bisque.endsAt, now), 'loading');
});

test('every seeded base batch totals 100', () => {
  const studio = expandStudio(undefined, new Date(2026, 10, 16, 9));
  for (const recipe of studio.recipes) {
    const baseTotal = recipe.ingredients
      .filter((item) => item.role === 'base')
      .reduce((sum, item) => sum + item.percentage, 0);
    assert.equal(baseTotal, 100, recipe.name);
  }
  assert.ok(studio.recipes.some((recipe) => recipe.name === 'Night Tenmoku'));
});

test('health, recipe list, and a rejected short batch', async () => {
  const health = await fetch(`${base()}/health`);
  assert.equal(health.status, 200);
  const healthBody = await health.json();
  assert.equal(healthBody.studio, 'East River Clay');

  const list = await fetch(`${base()}/recipes`);
  const listed = await list.json();
  assert.ok(listed.recipes.some((recipe) => recipe.name === 'Night Tenmoku'));

  const rejected = await fetch(`${base()}/recipes`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: 'Short batch',
      kind: 'glaze',
      coneMin: '6',
      coneMax: '6',
      atmosphere: 'oxidation',
      colorHex: '#E2C15A',
      colorName: 'yellow',
      surface: 'satin',
      description: '',
      firingNotes: '',
      author: 'Test',
      tested: false,
      ingredients: [{ name: 'Silica', percentage: 80, role: 'base' }],
    }),
  });
  assert.equal(rejected.status, 400);
  const error = await rejected.json();
  assert.match(error.error, /100%/);
});

test('a stale sync does not clobber a newer recipe, and a delete travels in the delta', async () => {
  const created = await fetch(`${base()}/recipes`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: 'Server Tenmoku',
      kind: 'glaze',
      coneMin: '8',
      coneMax: '10',
      atmosphere: 'reduction',
      colorHex: '#241816',
      colorName: 'iron black',
      surface: 'glossy',
      description: 'Written on the server.',
      firingNotes: 'Cone 9.',
      author: 'Mara Chen',
      tested: true,
      ingredients: [
        { name: 'Silica', percentage: 40, role: 'base' },
        { name: 'Feldspar', percentage: 60, role: 'base' },
      ],
    }),
  });
  assert.equal(created.status, 201);
  const saved = await created.json();

  const stale = await fetch(`${base()}/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      recipes: [{
        ...saved,
        name: 'Stale name',
        updatedAt: '2020-01-01T00:00:00.000Z',
      }],
      firings: [],
    }),
  });
  assert.equal(stale.status, 200);
  const staleBody = await stale.json();
  assert.equal(staleBody.conflicts.recipes.length, 1);
  assert.equal(staleBody.conflicts.recipes[0].name, 'Server Tenmoku');

  const renamedAt = new Date(Date.now() + 60_000).toISOString();
  const renamed = await fetch(`${base()}/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      recipes: [{ ...saved, name: 'Renamed Tenmoku', updatedAt: renamedAt, source: 'member' }],
      firings: [],
    }),
  });
  const renamedBody = await renamed.json();
  assert.equal(renamedBody.conflicts.recipes.length, 0);
  const afterRename = await fetch(`${base()}/recipes/${saved.id}`);
  assert.equal((await afterRename.json()).name, 'Renamed Tenmoku');

  const removedAt = new Date(Date.now() + 120_000).toISOString();
  const removed = await fetch(`${base()}/sync?since=${encodeURIComponent(renamedBody.serverTime)}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      recipes: [{
        ...saved,
        name: 'Renamed Tenmoku',
        updatedAt: removedAt,
        deletedAt: removedAt,
        source: 'member',
      }],
      firings: [],
    }),
  });
  assert.equal(removed.status, 200);
  const gone = await fetch(`${base()}/recipes/${saved.id}`);
  assert.equal(gone.status, 404);
  const delta = await fetch(`${base()}/sync?since=${encodeURIComponent(renamedBody.serverTime)}`);
  const deltaBody = await delta.json();
  const deleted = deltaBody.changes.recipes.find((recipe) => recipe.id === saved.id);
  assert.ok(deleted);
  assert.equal(deleted.deletedAt, removedAt);
});
