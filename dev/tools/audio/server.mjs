import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'

// Serves page.html, the web src (audio.js patched), jobs.json; collects POST /out/<name> into outDir.
export function serve({ web, jobs, outDir, onDone }) {
  const here = path.dirname(new URL(import.meta.url).pathname)
  const patch = (src) => {
    const once = (from, to) => { if (src.split(from).length !== 2) throw new Error('audio.js patch target not found exactly once: ' + from); src = src.replace(from, () => to) }
    once('wg.gain.value = 0.05', 'wg.gain.value = (globalThis.__WASH ?? 1) * 0.05')
    once('wash.frequency.value = 700', 'wash.frequency.value = globalThis.__WASHF ?? 700')
    return src + '\nexport const __t = { SFX, bell, tone, noise, PENT, pianoNote, startAmbience, M: () => M }\n'
  }
  const types = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json' }
  fs.mkdirSync(outDir, { recursive: true })
  const srv = http.createServer((req, res) => {
    const u = new URL(req.url, 'http://x')
    if (req.method === 'POST' && u.pathname.startsWith('/out/')) {
      const chunks = []
      req.on('data', (c) => chunks.push(c))
      req.on('end', () => {
        const name = u.pathname.slice(5)
        if (name === 'done') onDone()
        else { fs.mkdirSync(path.dirname(path.join(outDir, name)), { recursive: true }); fs.writeFileSync(path.join(outDir, name), Buffer.concat(chunks)) }
        res.end('ok')
      })
      return
    }
    if (u.pathname === '/') { res.setHeader('content-type', 'text/html'); return res.end(fs.readFileSync(path.join(here, 'page.html'))) }
    if (u.pathname === '/jobs.json') { res.setHeader('content-type', 'application/json'); return res.end(JSON.stringify(jobs)) }
    if (u.pathname.startsWith('/web/')) {
      const f = path.join(web, 'src', u.pathname.slice(5))
      if (!f.startsWith(path.join(web, 'src')) || !fs.existsSync(f)) { res.statusCode = 404; return res.end() }
      let body = fs.readFileSync(f, 'utf8')
      if (u.pathname === '/web/audio.js') body = patch(body)
      res.setHeader('content-type', types[path.extname(f)] || 'text/plain'); return res.end(body)
    }
    res.statusCode = 404; res.end()
  })
  return srv
}
