import crypto from 'node:crypto';

export const SEED_STAMP = '2026-01-01T00:00:00.000Z';

export const CONES = ['022', '06', '04', '02', '1', '2', '4', '5', '6', '8', '9', '10', '11', '12'];
function coneValue(label) {
  if (label.startsWith('0') && label.length > 1) return -Number(label.slice(1));
  return Number(label);
}

const KINDS = ['glaze', 'slip', 'engobe', 'wash'];
const ATMOSPHERES = ['oxidation', 'reduction', 'neutral', 'wood', 'soda', 'salt'];
const SURFACES = ['glossy', 'satin', 'matte', 'dry', 'crystalline'];
const ROLES = ['base', 'colorant', 'opacifier', 'additive'];
const STATUSES = ['scheduled', 'loading', 'firing', 'cooling', 'unloaded'];
const SOURCES = ['seed', 'member'];

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export function nowIso(date = new Date()) {
  return date.toISOString();
}

export function isoWeekKey(date) {
  const tmp = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = tmp.getUTCDay() || 7;
  tmp.setUTCDate(tmp.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(tmp.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((tmp - yearStart) / 86400000 + 1) / 7);
  return `${tmp.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

export function mondayOf(date) {
  const day = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = day.getDay() || 7;
  day.setDate(day.getDate() - (weekday - 1));
  day.setHours(0, 0, 0, 0);
  return day;
}

export function statusForWindow(startIso, endIso, now) {
  const start = new Date(startIso).getTime();
  const end = new Date(endIso).getTime();
  const time = now.getTime();
  if (time >= end) return 'unloaded';
  if (time >= start) {
    const elapsed = time - start;
    if (elapsed <= 90 * 60 * 1000) return 'loading';
    const totalMinutes = (end - start) / 60000;
    const coolingMinutes = Math.max(60, Math.round(totalMinutes * 0.2));
    if (end - time <= coolingMinutes * 60 * 1000) return 'cooling';
    return 'firing';
  }
  if (start - time <= 6 * 60 * 60 * 1000) return 'loading';
  return 'scheduled';
}

function requiredText(value, field, max) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new HttpError(400, `${field} is required.`);
  }
  const trimmed = value.trim();
  if (trimmed.length > max) {
    throw new HttpError(400, `${field} is too long.`);
  }
  return trimmed;
}

function optionalText(value, field, max) {
  if (value == null || value === '') return '';
  if (typeof value !== 'string') throw new HttpError(400, `${field} must be text.`);
  const trimmed = value.trim();
  if (trimmed.length > max) throw new HttpError(400, `${field} is too long.`);
  return trimmed;
}

function oneOf(value, field, allowed) {
  if (!allowed.includes(value)) {
    throw new HttpError(400, `${field} must be one of: ${allowed.join(', ')}.`);
  }
  return value;
}

function timestamp(value, field, fallback) {
  if (value == null || value === '') return fallback;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpError(400, `${field} is not a timestamp.`);
  }
  return date.toISOString();
}

function integer(value, field, min, max) {
  if (!Number.isInteger(value)) throw new HttpError(400, `${field} must be a whole number.`);
  if (value < min || value > max) throw new HttpError(400, `${field} is out of range.`);
  return value;
}

export function formatPercent(value) {
  const rounded = Math.round(value * 10) / 10;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
}

export function normalizeRecipe(input, { mode, clock }) {
  if (input == null || typeof input !== 'object' || Array.isArray(input)) {
    throw new HttpError(400, 'Recipe body must be an object.');
  }
  const stamp = clock ?? nowIso();
  let id = input.id;
  if (mode === 'sync') {
    id = requiredText(id, 'id', 80);
  } else if (id == null || id === '') {
    id = crypto.randomUUID();
  } else {
    id = requiredText(id, 'id', 80);
  }

  const coneMin = oneOf(input.coneMin, 'coneMin', CONES);
  const coneMax = oneOf(input.coneMax, 'coneMax', CONES);
  if (coneValue(coneMin) > coneValue(coneMax)) {
    throw new HttpError(400, 'Cone min has to be lower than cone max.');
  }
  const ingredients = normalizeIngredients(input.ingredients, id);
  const base = ingredients
    .filter((item) => item.role === 'base')
    .reduce((sum, item) => sum + item.percentage, 0);
  if (Math.abs(base - 100) > 0.15) {
    throw new HttpError(400, `Base materials must total 100%. They total ${formatPercent(base)}%.`);
  }

  const deletedAt = input.deletedAt == null || input.deletedAt === ''
    ? null
    : timestamp(input.deletedAt, 'deletedAt', stamp);

  return {
    id,
    name: requiredText(input.name, 'name', 80),
    kind: oneOf(input.kind, 'kind', KINDS),
    coneMin,
    coneMax,
    atmosphere: oneOf(input.atmosphere, 'atmosphere', ATMOSPHERES),
    colorHex: normalizeHex(input.colorHex),
    colorName: requiredText(input.colorName, 'colorName', 40),
    surface: oneOf(input.surface, 'surface', SURFACES),
    description: optionalText(input.description, 'description', 2000),
    firingNotes: optionalText(input.firingNotes, 'firingNotes', 2000),
    author: requiredText(input.author, 'author', 80),
    tested: input.tested === true,
    source: input.source == null ? 'member' : oneOf(input.source, 'source', SOURCES),
    createdAt: mode === 'sync' ? timestamp(input.createdAt, 'createdAt', stamp) : stamp,
    updatedAt: mode === 'sync' ? timestamp(input.updatedAt, 'updatedAt', stamp) : stamp,
    deletedAt,
    ingredients,
  };
}

function normalizeHex(value) {
  if (typeof value !== 'string' || !/^#[0-9A-Fa-f]{6}$/.test(value.trim())) {
    throw new HttpError(400, 'colorHex must look like #6E9A84.');
  }
  return value.trim().toUpperCase();
}

function normalizeIngredients(value, recipeId) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpError(400, 'Add at least one material.');
  }
  if (value.length > 40) throw new HttpError(400, 'A recipe can hold 40 materials.');
  return value.map((item, index) => {
    if (item == null || typeof item !== 'object') {
      throw new HttpError(400, 'Each material must be an object.');
    }
    const name = requiredText(item.name, 'ingredient name', 80);
    if (typeof item.percentage !== 'number' || Number.isNaN(item.percentage)) {
      throw new HttpError(400, `Enter a percentage for ${name}.`);
    }
    if (item.percentage <= 0 || item.percentage > 200) {
      throw new HttpError(400, 'Percentages have to be greater than zero.');
    }
    const id = typeof item.id === 'string' && item.id.trim() !== ''
      ? item.id.trim()
      : `${recipeId}:${index}`;
    return {
      id,
      name,
      percentage: item.percentage,
      role: oneOf(item.role, 'role', ROLES),
      sortOrder: index,
    };
  });
}

export function normalizeFiring(input, { mode, clock }) {
  if (input == null || typeof input !== 'object' || Array.isArray(input)) {
    throw new HttpError(400, 'Firing body must be an object.');
  }
  const stamp = clock ?? nowIso();
  let id = input.id;
  if (mode === 'sync') {
    id = requiredText(id, 'id', 80);
  } else if (id == null || id === '') {
    id = crypto.randomUUID();
  } else {
    id = requiredText(id, 'id', 80);
  }
  const startsAt = timestamp(input.startsAt, 'startsAt');
  const endsAt = timestamp(input.endsAt, 'endsAt');
  if (!startsAt || !endsAt || endsAt <= startsAt) {
    throw new HttpError(400, 'The firing has to end after it starts.');
  }
  const capacity = integer(input.capacity, 'capacity', 1, 500);
  const booked = integer(input.booked, 'booked', 0, capacity);
  const deletedAt = input.deletedAt == null || input.deletedAt === ''
    ? null
    : timestamp(input.deletedAt, 'deletedAt', stamp);
  return {
    id,
    title: requiredText(input.title, 'title', 80),
    kiln: requiredText(input.kiln, 'kiln', 80),
    startsAt,
    endsAt,
    cone: oneOf(input.cone, 'cone', CONES),
    atmosphere: oneOf(input.atmosphere, 'atmosphere', ATMOSPHERES),
    status: oneOf(input.status ?? 'scheduled', 'status', STATUSES),
    lead: requiredText(input.lead, 'lead', 80),
    notes: optionalText(input.notes, 'notes', 2000),
    capacity,
    booked,
    source: input.source == null ? 'member' : oneOf(input.source, 'source', SOURCES),
    createdAt: mode === 'sync' ? timestamp(input.createdAt, 'createdAt', stamp) : stamp,
    updatedAt: mode === 'sync' ? timestamp(input.updatedAt, 'updatedAt', stamp) : stamp,
    deletedAt,
  };
}
