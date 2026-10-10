import test from 'node:test'
import assert from 'node:assert/strict'
import { loadScript } from './lib.mjs'
const C = loadScript('logic/camera.js')

test('darkness is 0 at noon and 1 at midnight', () => {
  assert.ok(Math.abs(C.darkness(0.25)) < 1e-9)
  assert.ok(Math.abs(C.darkness(0.75) - 1) < 1e-9)
})
test('fitScale is an integer, at least 1, and fits', () => {
  assert.equal(C.fitScale(1920, 1080), 6)
  assert.equal(C.fitScale(3840, 800), 4)
  assert.equal(C.fitScale(100, 50), 1)
  assert.equal(C.fitScale(0, 0), 1)
})
test('nightMix splits darkness into a step and a fraction', () => {
  assert.deepEqual({ ...C.nightMix(0) }, { s0: 0, frac: 0 })
  const m = C.nightMix(0.5); assert.equal(m.s0, 1); assert.ok(Math.abs(m.frac - 0.5) < 1e-9)
  assert.deepEqual({ ...C.nightMix(1) }, { s0: 3, frac: 0 })
})
test('camera follows the player and clamps vertically', () => {
  const p = { x: 100, y: 5, face: 1 }
  const cam = C.makeCamera(p)
  assert.equal(cam.y, 90)
  for (let i = 0; i < 600; i++) C.updateCamera(cam, p, 1 / 60)
  assert.ok(Math.abs(cam.x - 122) < 0.5)
  assert.equal(Math.round(cam.y), 90)
})
