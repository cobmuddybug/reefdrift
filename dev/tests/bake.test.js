import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { Reef, ROOT, loadScript } from './lib.mjs'

const A = loadScript('ui/atlas.js')
const S = loadScript('ui/sprites.js')
const { SPECIES } = Reef.species

test('atlas image exists and every sprite rect is inside the sheet', () => {
  assert.ok(fs.existsSync(path.join(ROOT, 'sprites/atlas.png')))
  for (const [k, [x, y, w, h]] of Object.entries(A.SPRITES)) {
    assert.ok(x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= A.SHEET.w && y + h <= A.SHEET.h, k)
  }
  assert.ok(A.SHEET.h <= 8192)
})

test('every creature size in each species range resolves to a baked sprite, both facings, all frames', () => {
  for (const sp of Object.values(SPECIES)) {
    if (sp.id === 'plankton') continue
    for (let r = sp.rMin; r <= sp.rMax + 1e-9; r += 0.05) {
      for (const facing of [-1, 1]) for (const frame of [0, 1, 2, 3]) {
        if (frame > 1 && sp.id !== 'manta') continue
        assert.ok(S.lookup('c', sp.id, r, frame, facing), `${sp.id} r=${r.toFixed(2)} f=${frame} dir=${facing}`)
      }
    }
  }
})

test('school members (radius 0.9x to 1.1x of the spawn radius) also resolve', () => {
  for (const sp of Object.values(SPECIES).filter((q) => q.behaviour === 'school'))
    for (const r of [sp.rMin * 0.9, sp.rMax * 1.1]) for (const facing of [-1, 1])
      assert.ok(S.lookup('c', sp.id, r, 0, facing), `${sp.id} r=${r}`)
})

test('the player resolves at every growth stage', () => {
  for (let r = Reef.species.START_R; r <= Reef.species.MAX_R + 1e-9; r += 0.05)
    for (const facing of [-1, 1]) for (const frame of [0, 1]) assert.ok(S.lookup('p', null, r, frame, facing), `player r=${r.toFixed(2)}`)
})

test('every scenery feature of the world resolves in both frames', () => {
  const w = Reef.world.makeWorld(1)
  for (const f of w.features) for (const frame of [0, 1]) assert.ok(S.lookup('coral', f.kind, f.variant, frame, f.size), `${f.kind}/${f.variant}/${f.size}`)
})

test('a long simulated run only ever asks for baked sprites', () => {
  for (const r0 of [3, 8, 14, 20, 26]) {
    const g = Reef.sim.createGame({ seed: 1, r: r0 })
    for (let i = 0; i < 60 * 240; i++) {
      Reef.sim.step(g, Reef.bot.botInput(g), 1 / 60)
      if (i % 30) continue
      for (const c of g.creatures) {
        if (c.sp === 'plankton') continue
        assert.ok(S.lookup('c', c.sp, c.r, 0, c.face < 0 ? -1 : 1), `${c.sp} r=${c.r}`)
      }
      assert.ok(S.lookup('p', null, g.player.r, 0, g.player.face), `player r=${g.player.r}`)
    }
  }
})

test('layers, fade masks and font strips were baked', () => {
  for (const n of ['water', 'shafts', 'far', 'mid', 'sea']) for (let s = 0; s < 4; s++) assert.ok(fs.existsSync(path.join(ROOT, `sprites/layers/${n}-${s}.png`)), n + s)
  for (let l = 1; l <= 16; l++) assert.ok(fs.existsSync(path.join(ROOT, `sprites/fade/${l}.png`)))
  for (const k of ['white', 'yellow', 'w0', 'ink', 'w7', 'w6', 'w5', 'w4', 'teal']) assert.ok(fs.existsSync(path.join(ROOT, `sprites/font/${k}.png`)), k)
})
