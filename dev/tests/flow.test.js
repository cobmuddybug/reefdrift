import test from 'node:test'
import assert from 'node:assert/strict'
import { loadScript } from './lib.mjs'
const F = loadScript('logic/flow.js')

test('title items change once you have grown', () => {
  assert.deepEqual([...F.titleItems(false, false)], ['SWIM', 'SOUND ON'])
  assert.deepEqual([...F.titleItems(true, true)], ['CONTINUE', 'SOUND OFF', 'BEGIN ANEW'])
})
test('title menu moves, wraps and acts', () => {
  assert.equal(F.menuStep('title', 0, 'down', false).sel, 1)
  assert.equal(F.menuStep('title', 0, 'up', false).sel, 1)          // wraps (2 items)
  assert.equal(F.menuStep('title', 0, 'confirm', false).action, 'swim-fresh')
  assert.equal(F.menuStep('title', 0, 'confirm', true).action, 'swim')
  assert.equal(F.menuStep('title', 1, 'flick', false).action, 'mute')
  assert.equal(F.menuStep('title', 1, 'left', false).action, 'mute')
  assert.equal(F.menuStep('title', 2, 'confirm', true).action, 'anew')
})
test('pause menu', () => {
  assert.equal(F.menuStep('pause', 0, 'confirm', true).action, 'resume')
  assert.equal(F.menuStep('pause', 0, 'pause', true).action, 'resume')
  assert.equal(F.menuStep('pause', 3, 'confirm', true).action, 'title')
  assert.equal(F.menuStep('pause', 0, 'up', true).sel, 3)
})
test('readInput: keys steer, opposite keys cancel, flick is an edge', () => {
  let r = F.readInput({ a: 'left' }, { x: 0, y: 0, down: false }, { x: 160, y: 90 }, false)
  assert.ok(r.ax < 0 && r.ay === 0 && r.flick === false)
  r = F.readInput({ a: 'left', b: 'right', c: 'up' }, { x: 0, y: 0, down: false }, { x: 160, y: 90 }, true)
  assert.equal(r.ax, 0); assert.ok(r.ay < 0); assert.equal(r.flick, true)
})
test('readInput: unknown or garbage input never produces NaN', () => {
  const r = F.readInput({}, { x: NaN, y: undefined, down: true }, { x: 160, y: 90 }, false)
  assert.ok(Number.isFinite(r.ax) && Number.isFinite(r.ay))
})
test('pointerVector: nothing close, full speed far', () => {
  assert.deepEqual({ ...F.pointerVector(0, 0, 4, 0) }, { ax: 0, ay: 0 })
  assert.equal(F.pointerVector(0, 0, 100, 0).ax, 1)
})
