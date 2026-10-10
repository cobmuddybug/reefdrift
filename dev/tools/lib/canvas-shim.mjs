// Just enough canvas for the web sprite code: compile() only needs createElement('canvas'), getContext('2d'), fillStyle, fillRect.
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]
class Ctx {
  constructor(cv) { this.cv = cv; this.fillStyle = '#000000' }
  fillRect(x, y, w, h) {
    const [r, g, b] = hex(this.fillStyle), cv = this.cv
    for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) {
      if (i < 0 || j < 0 || i >= cv.width || j >= cv.height) continue
      const o = (j * cv.width + i) * 4
      cv.data[o] = r; cv.data[o + 1] = g; cv.data[o + 2] = b; cv.data[o + 3] = 255
    }
  }
}
export function installShim() {
  globalThis.document = { createElement: () => {
    const cv = { _w: 0, _h: 0, data: null, getContext() { return new Ctx(cv) } }
    for (const [p, o] of [['width', '_w'], ['height', '_h']]) Object.defineProperty(cv, p, { get: () => cv[o], set: (v) => { cv[o] = v; if (cv._w && cv._h) cv.data = new Uint8ClampedArray(cv._w * cv._h * 4) } })
    return cv
  } }
}
