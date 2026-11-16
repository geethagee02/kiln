import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { nowIso } from './validate.js';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS recipes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  cone_min TEXT NOT NULL,
  cone_max TEXT NOT NULL,
  atmosphere TEXT NOT NULL,
  color_hex TEXT NOT NULL,
  color_name TEXT NOT NULL,
  surface TEXT NOT NULL,
  description TEXT NOT NULL,
  firing_notes TEXT NOT NULL,
  author TEXT NOT NULL,
  tested INTEGER NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  synced_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE TABLE IF NOT EXISTS ingredients (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL,
  name TEXT NOT NULL,
  percentage REAL NOT NULL,
  role TEXT NOT NULL,
  sort_order INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS firings (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  kiln TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  cone TEXT NOT NULL,
  atmosphere TEXT NOT NULL,
  status TEXT NOT NULL,
  lead TEXT NOT NULL,
  notes TEXT NOT NULL,
  capacity INTEGER NOT NULL,
  booked INTEGER NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  synced_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_recipes_synced ON recipes(synced_at);
CREATE INDEX IF NOT EXISTS idx_firings_synced ON firings(synced_at);
CREATE INDEX IF NOT EXISTS idx_ingredients_recipe ON ingredients(recipe_id);
`;

export function openDatabase(dbPath) {
  mkdirSync(dirname(dbPath), { recursive: true });
  const db = new DatabaseSync(dbPath);
  db.exec('PRAGMA foreign_keys = ON');
  db.exec(SCHEMA);
  return db;
}

export function transaction(db, fn) {
  db.exec('BEGIN');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    try {
      db.exec('ROLLBACK');
    } catch {
      // The original error is the one worth surfacing.
    }
    throw error;
  }
}

export function countRecipes(db) {
  return Number(db.prepare('SELECT COUNT(*) AS c FROM recipes').get().c);
}

export function hasRecipe(db, id) {
  return Boolean(db.prepare('SELECT 1 AS ok FROM recipes WHERE id = ?').get(id));
}

export function hasFiring(db, id) {
  return Boolean(db.prepare('SELECT 1 AS ok FROM firings WHERE id = ?').get(id));
}

export function writeRecipe(db, recipe, syncedAt = nowIso()) {
  db.prepare('DELETE FROM ingredients WHERE recipe_id = ?').run(recipe.id);
  db.prepare(`
    INSERT OR REPLACE INTO recipes (
      id, name, kind, cone_min, cone_max, atmosphere, color_hex, color_name,
      surface, description, firing_notes, author, tested, source,
      created_at, updated_at, synced_at, deleted_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    recipe.id,
    recipe.name,
    recipe.kind,
    recipe.coneMin,
    recipe.coneMax,
    recipe.atmosphere,
    recipe.colorHex,
    recipe.colorName,
    recipe.surface,
    recipe.description,
    recipe.firingNotes,
    recipe.author,
    recipe.tested ? 1 : 0,
    recipe.source,
    recipe.createdAt,
    recipe.updatedAt,
    syncedAt,
    recipe.deletedAt,
  );
  const insert = db.prepare(`
    INSERT INTO ingredients (id, recipe_id, name, percentage, role, sort_order)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  for (const item of recipe.ingredients) {
    insert.run(item.id, recipe.id, item.name, item.percentage, item.role, item.sortOrder);
  }
}

export function writeFiring(db, firing, syncedAt = nowIso()) {
  db.prepare(`
    INSERT OR REPLACE INTO firings (
      id, title, kiln, starts_at, ends_at, cone, atmosphere, status, lead, notes,
      capacity, booked, source, created_at, updated_at, synced_at, deleted_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    firing.id,
    firing.title,
    firing.kiln,
    firing.startsAt,
    firing.endsAt,
    firing.cone,
    firing.atmosphere,
    firing.status,
    firing.lead,
    firing.notes,
    firing.capacity,
    firing.booked,
    firing.source,
    firing.createdAt,
    firing.updatedAt,
    syncedAt,
    firing.deletedAt,
  );
}

function mapRecipe(row, ingredients) {
  return {
    id: row.id,
    name: row.name,
    kind: row.kind,
    coneMin: row.cone_min,
    coneMax: row.cone_max,
    atmosphere: row.atmosphere,
    colorHex: row.color_hex,
    colorName: row.color_name,
    surface: row.surface,
    description: row.description,
    firingNotes: row.firing_notes,
    author: row.author,
    tested: row.tested === 1,
    source: row.source,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
    ingredients: ingredients.map((item) => ({
      id: item.id,
      name: item.name,
      percentage: item.percentage,
      role: item.role,
      sortOrder: item.sort_order,
    })),
  };
}

function mapFiring(row) {
  return {
    id: row.id,
    title: row.title,
    kiln: row.kiln,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    cone: row.cone,
    atmosphere: row.atmosphere,
    status: row.status,
    lead: row.lead,
    notes: row.notes,
    capacity: row.capacity,
    booked: row.booked,
    source: row.source,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  };
}

function ingredientsByRecipe(db) {
  const grouped = new Map();
  for (const row of db.prepare('SELECT * FROM ingredients ORDER BY sort_order').all()) {
    const list = grouped.get(row.recipe_id) ?? [];
    list.push(row);
    grouped.set(row.recipe_id, list);
  }
  return grouped;
}

export function loadRecipes(db, { since = null, includeDeleted = false } = {}) {
  const params = [];
  let sql = 'SELECT * FROM recipes WHERE 1 = 1';
  if (since) {
    sql += ' AND synced_at > ?';
    params.push(since);
  } else if (!includeDeleted) {
    sql += ' AND deleted_at IS NULL';
  }
  sql += ' ORDER BY name COLLATE NOCASE';
  const grouped = ingredientsByRecipe(db);
  return db.prepare(sql).all(...params).map((row) => mapRecipe(row, grouped.get(row.id) ?? []));
}

export function loadRecipe(db, id) {
  const row = db.prepare('SELECT * FROM recipes WHERE id = ?').get(id);
  if (!row || row.deleted_at) return null;
  const ingredients = db.prepare(
    'SELECT * FROM ingredients WHERE recipe_id = ? ORDER BY sort_order',
  ).all(id);
  return mapRecipe(row, ingredients);
}

export function loadRecipeRaw(db, id) {
  const row = db.prepare('SELECT * FROM recipes WHERE id = ?').get(id);
  if (!row) return null;
  const ingredients = db.prepare(
    'SELECT * FROM ingredients WHERE recipe_id = ? ORDER BY sort_order',
  ).all(id);
  return mapRecipe(row, ingredients);
}

export function loadFirings(db, { since = null } = {}) {
  const params = [];
  let sql = 'SELECT * FROM firings WHERE 1 = 1';
  if (since) {
    sql += ' AND synced_at > ?';
    params.push(since);
  } else {
    sql += ' AND deleted_at IS NULL';
  }
  sql += ' ORDER BY starts_at';
  return db.prepare(sql).all(...params).map(mapFiring);
}

export function loadFiring(db, id) {
  const row = db.prepare('SELECT * FROM firings WHERE id = ? AND deleted_at IS NULL').get(id);
  return row ? mapFiring(row) : null;
}

function existingStamp(db, table, id) {
  const row = db.prepare(`SELECT updated_at FROM ${table} WHERE id = ?`).get(id);
  return row?.updated_at ?? null;
}

export function applyIncoming(db, { recipes, firings, clock }) {
  const conflicts = { recipes: [], firings: [] };
  let applied = 0;
  const syncedAt = clock;
  for (const recipe of recipes) {
    const current = existingStamp(db, 'recipes', recipe.id);
    if (current && current > recipe.updatedAt) {
      conflicts.recipes.push(loadRecipeRaw(db, recipe.id));
      continue;
    }
    writeRecipe(db, recipe, syncedAt);
    applied += 1;
  }
  for (const firing of firings) {
    const current = existingStamp(db, 'firings', firing.id);
    if (current && current > firing.updatedAt) {
      const row = db.prepare('SELECT * FROM firings WHERE id = ?').get(firing.id);
      conflicts.firings.push(mapFiring(row));
      continue;
    }
    writeFiring(db, firing, syncedAt);
    applied += 1;
  }
  return { applied, conflicts };
}
