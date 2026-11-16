import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from './app.js';

const host = process.env.HOST || '127.0.0.1';
const port = Number(process.env.PORT || 8787);
const dbPath = process.env.KILN_DB
  || join(dirname(fileURLToPath(import.meta.url)), 'data', 'kiln.sqlite');

const running = await createServer({ dbPath, host, port });
console.log(`Kiln API listening on http://${host}:${running.port}`);
console.log(`Database: ${dbPath}`);
