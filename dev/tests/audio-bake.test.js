import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync, spawnSync } from 'node:child_process'
import { Reef, ROOT, loadScript } from './lib.mjs'

const S = loadScript('ui/sounds.js')
const probe = (rel) => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'json', path.join(ROOT, 'sounds', rel)]).toString()).format

test('every sound in the table exists and has non-trivial length', () => {
  const files = [...S.EAT.map((e) => e.file), ...S.CHIMES, ...Object.values(S.TRACKS), ...Object.values(S.WASH),
    ...['flick', 'scatter', 'respawn', 'warn', 'dizzy', 'whale', 'fullgrown', 'menu', 'confirm'].map((n) => S.SFX[n])]
  for (const f of files) { assert.ok(fs.existsSync(path.join(ROOT, 'sounds', f)), f); assert.ok(Number(probe(f).duration) > 0.05, f) }
})

test('every web track has a baked file and the right length', () => {
  for (const id of Object.keys(Reef['music/tracks'].TRACK_DATA)) {
    assert.ok(S.TRACKS[id], id)
    const want = Reef.music.prepare(id).length
    assert.ok(Math.abs(Number(probe(S.TRACKS[id]).duration) - want) < 12, `${id}: ${probe(S.TRACKS[id]).duration} vs ${want}`)
  }
})

test('eatFile picks the nearest pitch bucket', () => {
  assert.equal(S.eatFile(0.7), S.EAT[0].file)
  assert.equal(S.eatFile(100), S.EAT[S.EAT.length - 1].file)
})

test('wash loops are 100 s (seamless: 7 LFO cycles of the 0.07 Hz breathing, 50 reps of the 2 s noise)', () => {
  for (const f of Object.values(S.WASH)) assert.ok(Math.abs(Number(probe(f).duration) - 100) < 0.5, f)
})

test('no baked file is silent or clipped', () => {
  for (const f of [S.SFX.flick, S.SFX.scatter, S.CHIMES[0], S.TRACKS.gymnopedie1, S.WASH.mid]) {
    const err = spawnSync('ffmpeg', ['-i', path.join(ROOT, 'sounds', f), '-af', 'volumedetect', '-f', 'null', '-'], { encoding: 'utf8' }).stderr
    const max = Number(err.match(/max_volume: (-?[\d.]+) dB/)[1]), mean = Number(err.match(/mean_volume: (-?[\d.]+) dB/)[1])
    assert.ok(max < -0.1, `${f} clips (${max} dB)`)
    assert.ok(mean > -70, `${f} is silent (${mean} dB)`)
  }
})
