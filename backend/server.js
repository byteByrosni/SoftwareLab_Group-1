const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const app = express();
const PORT = process.env.PORT || 4000;
const webBuildDir = path.join(__dirname, '..', 'build', 'web');
const models = { users: prisma.user, markets: prisma.market, prices: prisma.price };

app.disable('x-powered-by');
app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

app.use('/api', (req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

async function readCollection(model) {
  const rows = await model.findMany();
  return rows.map((row) => JSON.parse(row.data));
}

app.get('/api/health', (req, res) => {
  res.json({ ok: true, ts: Date.now() });
});

app.get('/api/snapshot', async (req, res, next) => {
  try {
    const [markets, users, prices] = await Promise.all([
      readCollection(prisma.market),
      readCollection(prisma.user),
      readCollection(prisma.price),
    ]);
    res.json({ markets, users, prices });
  } catch (err) {
    next(err);
  }
});

// GET /api/:collection  -> list all docs, decoded from JSON
app.get('/api/:collection', async (req, res, next) => {
  try {
    const model = models[req.params.collection];
    if (!model) return res.status(404).json({ error: 'unknown collection' });
    res.json(await readCollection(model));
  } catch (err) {
    next(err);
  }
});

// PUT /api/:collection/:id  -> upsert one doc
app.put('/api/:collection/:id', async (req, res, next) => {
  try {
    const model = models[req.params.collection];
    if (!model) return res.status(404).json({ error: 'unknown collection' });
    const data = JSON.stringify(req.body);
    const row = await model.upsert({
      where: { id: req.params.id },
      update: { data },
      create: { id: req.params.id, data },
    });
    res.json(JSON.parse(row.data));
  } catch (err) {
    next(err);
  }
});

// Flutter's build output is NOT content-hashed — main.dart.js keeps the exact
// same filename across every build. `Cache-Control` headers only govern how
// long an ALREADY-cached response stays valid; they do nothing for a client
// that cached the file under a past (looser) policy and won't even ask the
// server again until its own stale expiry passes. So a client that loaded the
// app before this fix can keep serving old code indefinitely, regardless of
// what headers the server sends now.
//
// The only fix that can't be defeated by a client's existing cache is to
// change the URL itself. flutter_bootstrap.js is what tells the browser which
// script to load next (main.dart.js), so we rewrite that one reference at
// request time to include `?v=<main.dart.js's mtime>`. Every rebuild changes
// the mtime, so every rebuild is a brand-new URL no client has ever cached —
// guaranteed fresh fetch, independent of any cache policy already in effect
// on that device.
app.get('/flutter_bootstrap.js', (req, res, next) => {
  const bootstrapPath = path.join(webBuildDir, 'flutter_bootstrap.js');
  const mainJsPath = path.join(webBuildDir, 'main.dart.js');
  fs.readFile(bootstrapPath, 'utf8', (err, content) => {
    if (err) return next();
    let version = Date.now();
    try {
      version = fs.statSync(mainJsPath).mtimeMs;
    } catch {}
    const versioned = content.replaceAll('"main.dart.js"', `"main.dart.js?v=${version}"`);
    res.set('Content-Type', 'application/javascript');
    res.set('Cache-Control', 'no-cache');
    res.send(versioned);
  });
});

// Serve the Flutter web release build so the PWA and API can share one ngrok URL.
// Everything else is served no-cache too (revalidate via ETag, so repeat loads
// are still cheap 304s) as defense in depth alongside the versioning above.
app.use(express.static(webBuildDir, {
  etag: true,
  lastModified: true,
  maxAge: 0,
  setHeaders(res) {
    res.set('Cache-Control', 'no-cache');
  },
}));

// PWA refresh/deep-link fallback.
app.use((req, res, next) => {
  if (req.method !== 'GET' || req.path.startsWith('/api/')) return next();
  res.sendFile(path.join(webBuildDir, 'index.html'));
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`KB backend + PWA on http://0.0.0.0:${PORT}`);
});
