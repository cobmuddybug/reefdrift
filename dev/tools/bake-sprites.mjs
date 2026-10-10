#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { installShim } from './lib/canvas-shim.mjs'
import { encodePng } from './lib/png.mjs'

installShim()
const WEB = process.env.REEF_WEB || path.join(process.env.HOME, 'Projects/reef-drift')
const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '../..')
const web = (f) => import(pathToFileURL(path.join(WEB, 'src', f)).href)
const { creatureSprite, playerSprite, coralSprite, fishLength } = await web('sprites.js')
const { PAL } = await web('palette.js')
const { SPECIES, START_R, MAX_R } = await web('species.js')
const { makeWorld, WORLD_W, WORLD_H, floorAt } = await web('world.js')

const out = (rel, buf) => { const f = path.join(ROOT, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, buf) }
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]

// ---- 1. enumerate sprites (keys identical to the web memo keys) ----
const items = new Map()   // key -> canvas shim {width,height,data}
const add = (key, cv) => { if (!items.has(key)) items.set(key, cv) }
for (const sp of Object.values(SPECIES)) {
  if (sp.id === 'plankton') continue
  const sym = sp.id === 'jellyfish', frames = sp.id === 'manta' ? 4 : 2
  // school members are spawned at 0.9x..1.1x of the drawn radius, so bake that wider range
  for (let r = sp.rMin * 0.9; r <= sp.rMax * 1.1 + 1e-9; r += 0.01) {
    const L = fishLength(r, sp.id)
    for (let f = 0; f < frames; f++) for (const facing of sym ? [1] : [-1, 1]) add(`c:${sp.id}:${L}:${f}:${sym ? 0 : facing}`, creatureSprite(sp.id, r, f, facing))
  }
}
for (let r = START_R; r <= MAX_R + 1e-9; r += 0.01) {
  const L = fishLength(r)
  for (let f = 0; f < 2; f++) for (const facing of [-1, 1]) add(`p:${L}:${f}:${facing}`, playerSprite(r, f, facing))
}
for (const f of makeWorld(1).features) for (let fr = 0; fr < 2; fr++) {
  const size = Math.max(6, Math.round(f.size))
  add(`coral:${f.kind}:${f.variant % 4}:${size}:${fr}`, coralSprite(f.kind, f.variant, f.size, fr))
}

// ---- 2. shelf-pack, tallest first ----
const SW = 2048
const list = [...items.entries()].sort((a, b) => b[1].height - a[1].height || b[1].width - a[1].width)
const pos = {}; let x = 0, y = 0, rowH = 0
for (const [k, cv] of list) {
  if (x + cv.width + 1 > SW) { x = 0; y += rowH + 1; rowH = 0 }
  pos[k] = [x, y, cv.width, cv.height]; x += cv.width + 1; rowH = Math.max(rowH, cv.height)
}
const SH = y + rowH
const sheet = new Uint8ClampedArray(SW * SH * 4)
for (const [k, cv] of list) {
  const [px, py, w, h] = pos[k]
  for (let j = 0; j < h; j++) sheet.set(cv.data.subarray(j * w * 4, (j + 1) * w * 4), ((py + j) * SW + px) * 4)
}
out('sprites/atlas.png', encodePng(SW, SH, sheet))

// ---- 3. font strips (one per palette colour) ----
const fontSrc = fs.readFileSync(path.join(WEB, 'src/font.js'), 'utf8')
const G = Function(fontSrc.match(/const G = (\{[\s\S]*?\n\})\n/)[1].replace(/^/, 'return '))()
const ORDER = Object.keys(G), CELL = 6
for (const [name, col] of Object.entries(PAL)) {
  const w = ORDER.length * CELL, buf = new Uint8ClampedArray(w * 7 * 4), [r, g, b] = hex(col)
  ORDER.forEach((ch, i) => G[ch].split('/').forEach((row, yy) => { for (let xx = 0; xx < 5; xx++) if (row[xx] === '#') { const o = (yy * w + i * CELL + xx) * 4; buf[o] = r; buf[o + 1] = g; buf[o + 2] = b; buf[o + 3] = 255 } }))
  out(`sprites/font/${name}.png`, encodePng(w, 7, buf))
}

// ---- 4. world layers per night step (ported 1:1 from render.js `layers`, which is not exported) ----
const RAMP = ['w0', 'w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7'], BAND = WORLD_H / 8
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5], bayer = (x, y) => BAYER[(y & 3) * 4 + (x & 3)]
const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2246822519) | 0; h = (h ^ (h >> 13)) * 1274126177 | 0; return ((h ^ (h >> 16)) >>> 0) / 4294967296 }
function waterKey(x, y, shift = 0) {
  const f = Math.max(0, Math.min(WORLD_H - 0.01, y)) / BAND
  let i = Math.floor(f); const t = (f - i - 0.8) / 0.2
  if (t > 0 && bayer(x, y) < t * 16) i++
  return RAMP[Math.max(0, Math.min(7, i + shift))]
}
function pix(w, h, fn) {
  const buf = new Uint8ClampedArray(w * h * 4), cache = {}
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const k = fn(i, j); if (!k) continue
    const c = cache[k] || (cache[k] = hex(PAL[k])), o = (j * w + i) * 4
    buf[o] = c[0]; buf[o + 1] = c[1]; buf[o + 2] = c[2]; buf[o + 3] = 255
  }
  return encodePng(w, h, buf)
}
const world = makeWorld(1), seed = world.seed, SAND = ['sand', 'sandDk', 'sandSh', 'grayDk', 'w6', 'w7']
for (let shift = 0; shift <= 3; shift++) {
  const sandKey = (i) => SAND[Math.min(SAND.length - 1, i + shift)]
  out(`sprites/layers/water-${shift}.png`, pix(320, WORLD_H, (x, y) => waterKey(x, y, shift)))
  out(`sprites/layers/shafts-${shift}.png`, pix(320 + 56, 300, (x, y) => {
    const u = (x + y * 0.55) % 56; if (u > 13) return null
    const level = (1 - y / 300) * 0.85 * (1 - shift / 3)
    return bayer(x, y) < level * 16 ? waterKey(x, y, shift - 1) : null
  }))
  const ridge = (P, sh, a, b, base, amp) => pix(P, WORLD_H, (x, y) => {
    const top = base + amp * Math.sin((2 * Math.PI * x) / P + a) + amp * 0.3 * Math.sin((6 * Math.PI * x) / P + b)
    return y >= top ? waterKey(x, y, shift + sh) : null
  })
  out(`sprites/layers/far-${shift}.png`, ridge(Math.round(WORLD_W * 0.3), 2, seed, seed * 2, 250, 90))
  out(`sprites/layers/mid-${shift}.png`, ridge(Math.round(WORLD_W * 0.6), 1, seed * 3, seed, 330, 80))
  out(`sprites/layers/sea-${shift}.png`, pix(WORLD_W, WORLD_H, (x, y) => {
    const fy = floorAt(world, x); if (y < fy - 0.5) return null
    const d = y - fy, base = y < 190 ? 0 : y < 330 ? 1 : y < 450 ? 2 : 3
    if (d < 2) return sandKey(base)
    const ripple = Math.sin(y * 0.55 + Math.sin(x * 0.07) * 2.2 + Math.sin(x * 0.19) * 0.7) > 0.82
    return ripple || hash(x, y) < 0.04 ? sandKey(base + 1) : sandKey(base)
  }))
}
// fade-out dither masks, w7, level 1..16 (the scatter fade)
for (let l = 1; l <= 16; l++) out(`sprites/fade/${l}.png`, pix(320, 180, (x, y) => (bayer(x, y) < l ? 'w7' : null)))

// ---- 5. runtime tables ----
const js = `.pragma library\n// GENERATED by dev/tools/bake-sprites.mjs. Do not edit.\n` +
  `var SHEET = ${JSON.stringify({ w: SW, h: SH })}\nvar SPRITES = ${JSON.stringify(pos)}\nvar GLYPHS = ${JSON.stringify(ORDER.join(''))}\nvar GLYPH_CELL = ${CELL}\nvar PAL = ${JSON.stringify(PAL)}\n`
out('ui/atlas.js', js)
console.log(`baked ${items.size} sprites into ${SW}x${SH}`)
