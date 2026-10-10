import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { ROOT } from './lib.mjs'

const m = JSON.parse(fs.readFileSync(path.join(ROOT, 'manifest.json'), 'utf8'))

test('manifest keeps the overlay loaded so a swim survives closing it and IPC always has a target', () => {
  assert.equal(m.keepLoaded, true)
})
test('manifest id matches the IPC target used by the overlay and the README', () => {
  assert.equal(m.id, 'io.github.cobmuddybug.reefdrift')
  assert.ok(fs.readFileSync(path.join(ROOT, 'Overlay.qml'), 'utf8').includes('target: "' + m.id + '"'))
})
