import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hasFiring, hasRecipe, transaction, writeFiring, writeRecipe } from './db.js';
import {
  SEED_STAMP,
  isoWeekKey,
  mondayOf,
  statusForWindow,
} from './validate.js';

const seedPath = join(dirname(fileURLToPath(import.meta.url)), '../assets/seed/studio.json');

export function readSeedFile() {
  return JSON.parse(readFileSync(seedPath, 'utf8'));
}

export function expandStudio(raw = null, now = new Date()) {
  const studio = raw == null
    ? readSeedFile()
    : typeof raw === 'string'
      ? JSON.parse(raw)
      : raw;
  const monday = mondayOf(now);
  const recipes = studio.recipes.map((recipe) => ({
    id: recipe.id,
    name: recipe.name,
    kind: recipe.kind,
    coneMin: recipe.coneMin,
    coneMax: recipe.coneMax,
    atmosphere: recipe.atmosphere,
    colorHex: recipe.colorHex.toUpperCase(),
    colorName: recipe.colorName,
    surface: recipe.surface,
    description: recipe.description,
    firingNotes: recipe.firingNotes,
    author: recipe.author,
    tested: recipe.tested === true,
    source: 'seed',
    createdAt: SEED_STAMP,
    updatedAt: SEED_STAMP,
    deletedAt: null,
    ingredients: recipe.ingredients.map((item, index) => ({
      id: `${recipe.id}:${index}`,
      name: item.name,
      percentage: item.percentage,
      role: item.role,
      sortOrder: index,
    })),
  }));

  const firings = studio.firingTemplates.map((template) => {
    const start = new Date(
      monday.getFullYear(),
      monday.getMonth(),
      monday.getDate() + template.dayOffset,
      template.startHour,
      0,
      0,
      0,
    );
    const end = new Date(start.getTime() + template.durationHours * 3600000);
    const startsAt = start.toISOString();
    const endsAt = end.toISOString();
    return {
      id: `firing-${isoWeekKey(start)}-${template.idSuffix}`,
      title: template.title,
      kiln: template.kiln,
      startsAt,
      endsAt,
      cone: template.cone,
      atmosphere: template.atmosphere,
      status: statusForWindow(startsAt, endsAt, now),
      lead: template.lead,
      notes: template.notes,
      capacity: template.capacity,
      booked: template.booked,
      source: 'seed',
      createdAt: SEED_STAMP,
      updatedAt: SEED_STAMP,
      deletedAt: null,
    };
  });

  return { studio: studio.studio, recipes, firings };
}

export function ensureSeed(db, now = new Date()) {
  const studio = expandStudio(readSeedFile(), now);
  transaction(db, () => {
    for (const recipe of studio.recipes) {
      if (!hasRecipe(db, recipe.id)) writeRecipe(db, recipe, SEED_STAMP);
    }
    for (const firing of studio.firings) {
      if (!hasFiring(db, firing.id)) writeFiring(db, firing, SEED_STAMP);
    }
  });
  return studio;
}

export function presentFiring(firing, now = new Date()) {
  if (firing.source !== 'seed' || firing.deletedAt) return firing;
  return {
    ...firing,
    status: statusForWindow(firing.startsAt, firing.endsAt, now),
  };
}
