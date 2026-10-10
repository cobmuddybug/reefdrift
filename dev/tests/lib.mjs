// Evaluates the plugin's QML JavaScript libraries the way QML would (plain script, `.pragma library`,
// `.import "x.js" as N`) and exports Reef.
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { fileURLToPath } from 'node:url'

export const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..')
const cache = {}

export function loadScript(rel, globals = {}) {
  const file = path.resolve(ROOT, rel)
  if (!Object.keys(globals).length && cache[file]) return cache[file]
  let src = fs.readFileSync(file, 'utf8')
  src = src.replace(/^\.pragma library\s*$/m, '')
  const deps = {}
  src = src.replace(/^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/mg, (m, p, name) => {
    deps[name] = loadScript(path.relative(ROOT, path.join(path.dirname(file), p)))
    return ''
  })
  // Run in this realm (not a vm context) so arrays and objects compare equal with assert.deepStrictEqual.
  // the Reef bundle keeps its module functions at column 0 inside one IIFE, so only `Reef` is top level there
  const names = src.includes('var Reef = (function') ? ['Reef'] : [...src.matchAll(/^(?:var|function)\s+([A-Za-z_$][\w$]*)/gm)].map((m) => m[1])
  const args = { ...deps, ...globals }
  const fn = new Function(...Object.keys(args), src + `\nreturn { ${[...new Set(names)].join(', ')} }`)
  const out = fn(...Object.values(args))
  if (!Object.keys(globals).length) cache[file] = out
  return out
}

export const Reef = loadScript('logic/reef.js').Reef
