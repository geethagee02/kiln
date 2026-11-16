import http from 'node:http';
import {
  applyIncoming,
  loadFiring,
  loadFirings,
  loadRecipe,
  loadRecipes,
  openDatabase,
  transaction,
  writeFiring,
  writeRecipe,
} from './db.js';
import { ensureSeed, presentFiring, readSeedFile } from './seed.js';
import { HttpError, normalizeFiring, normalizeRecipe, nowIso } from './validate.js';

const studioName = readSeedFile().studio;

function send(res, status, payload) {
  const body = payload == null ? '' : JSON.stringify(payload);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'access-control-allow-headers': 'content-type',
    'content-length': Buffer.byteLength(body),
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1_000_000) {
        reject(new HttpError(413, 'Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (chunks.length === 0) {
        resolve(null);
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new HttpError(400, 'Body must be JSON.'));
      }
    });
    req.on('error', reject);
  });
}

export function syncDatabase(db, body, since, clock = nowIso()) {
  const recipes = Array.isArray(body?.recipes) ? body.recipes : null;
  const firings = Array.isArray(body?.firings) ? body.firings : null;
  if (!recipes || !firings) {
    throw new HttpError(400, 'Sync body needs recipes and firings arrays.');
  }
  const normalizedRecipes = recipes.map((recipe) => normalizeRecipe(recipe, { mode: 'sync', clock }));
  const normalizedFirings = firings.map((firing) => normalizeFiring(firing, { mode: 'sync', clock }));
  return transaction(db, () => {
    const { applied, conflicts } = applyIncoming(db, {
      recipes: normalizedRecipes,
      firings: normalizedFirings,
      clock,
    });
    const changes = {
      recipes: loadRecipes(db, { since: since || null, includeDeleted: Boolean(since) }),
      firings: loadFirings(db, { since: since || null }).map((firing) => presentFiring(firing, new Date(clock))),
    };
    return { serverTime: clock, applied, conflicts, changes };
  });
}

export function handleRequest(db, req, res, body, clock = nowIso()) {
  const url = new URL(req.url ?? '/', 'http://localhost');
  const parts = url.pathname.split('/').filter(Boolean);
  const method = req.method ?? 'GET';
  if (method === 'OPTIONS') {
    send(res, 204, null);
    return;
  }
  ensureSeed(db, new Date(clock));

  if (method === 'GET' && parts.length === 1 && parts[0] === 'health') {
    send(res, 200, { ok: true, service: 'kiln', studio: studioName, time: clock });
    return;
  }

  if (parts[0] === 'sync' && parts.length === 1 && (method === 'GET' || method === 'POST')) {
    const since = url.searchParams.get('since');
    const payload = method === 'GET' ? { recipes: [], firings: [] } : body;
    send(res, 200, syncDatabase(db, payload, since, clock));
    return;
  }

  if (parts[0] === 'recipes' && parts.length === 1 && method === 'GET') {
    send(res, 200, { recipes: loadRecipes(db) });
    return;
  }

  if (parts[0] === 'recipes' && parts.length === 1 && method === 'POST') {
    const recipe = normalizeRecipe(body, { mode: 'create', clock });
    transaction(db, () => writeRecipe(db, recipe, clock));
    send(res, 201, loadRecipe(db, recipe.id));
    return;
  }

  if (parts[0] === 'recipes' && parts.length === 2 && method === 'GET') {
    const recipe = loadRecipe(db, parts[1]);
    if (!recipe) throw new HttpError(404, 'Recipe not found.');
    send(res, 200, recipe);
    return;
  }

  if (parts[0] === 'recipes' && parts.length === 2 && method === 'PUT') {
    const recipe = normalizeRecipe({ ...body, id: parts[1] }, { mode: 'sync', clock });
    transaction(db, () => writeRecipe(db, { ...recipe, updatedAt: clock, source: 'member' }, clock));
    send(res, 200, loadRecipe(db, parts[1]));
    return;
  }

  if (parts[0] === 'recipes' && parts.length === 2 && method === 'DELETE') {
    const existing = loadRecipe(db, parts[1]);
    if (!existing) throw new HttpError(404, 'Recipe not found.');
    const deleted = { ...existing, deletedAt: clock, updatedAt: clock, source: 'member' };
    transaction(db, () => writeRecipe(db, deleted, clock));
    send(res, 200, { ok: true, id: parts[1] });
    return;
  }

  if (parts[0] === 'firings' && parts.length === 1 && method === 'GET') {
    const now = new Date(clock);
    send(res, 200, { firings: loadFirings(db).map((firing) => presentFiring(firing, now)) });
    return;
  }

  if (parts[0] === 'firings' && parts.length === 1 && method === 'POST') {
    const firing = normalizeFiring(body, { mode: 'create', clock });
    transaction(db, () => writeFiring(db, firing, clock));
    send(res, 201, loadFiring(db, firing.id));
    return;
  }

  throw new HttpError(404, 'No such route.');
}

export function createServer({ dbPath, host = '127.0.0.1', port = 0, clock } = {}) {
  const db = openDatabase(dbPath);
  ensureSeed(db, clock ? new Date(clock()) : new Date());
  const server = http.createServer(async (req, res) => {
    try {
      const body = await readBody(req);
      const now = clock ? clock() : nowIso();
      handleRequest(db, req, res, body, now);
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      const message = error instanceof HttpError ? error.message : 'The studio service hit an unexpected error.';
      if (status === 500) console.error(error);
      if (!res.headersSent) send(res, status, { error: message });
    }
  });
  return new Promise((resolve) => {
    server.listen(port, host, () => {
      const address = server.address();
      resolve({
        server,
        db,
        host,
        port: typeof address === 'object' && address ? address.port : port,
        close: () => new Promise((done, reject) => {
          server.close((error) => {
            try {
              db.close();
            } catch {
              // Already closed.
            }
            if (error) reject(error);
            else done();
          });
        }),
      });
    });
  });
}
