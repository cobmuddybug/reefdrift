.pragma library
.import "reef.js" as R

function titleItems(grown, muted) {
  var a = [grown ? "CONTINUE" : "SWIM", "SOUND " + (muted ? "OFF" : "ON")]
  if (grown) a.push("BEGIN ANEW")
  return a
}
function pauseItems(muted) { return ["RESUME", "SOUND " + (muted ? "OFF" : "ON"), "BEGIN ANEW", "TITLE"] }

function menuStep(menu, sel, key, grown) {
  var n = menu === "title" ? (grown ? 3 : 2) : 4
  var confirm = key === "confirm" || key === "flick"
  if (key === "up") return { sel: (sel + n - 1) % n, action: null }
  if (key === "down") return { sel: (sel + 1) % n, action: null }
  if (menu === "pause" && key === "pause") return { sel: sel, action: "resume" }
  if (!(confirm || (sel === 1 && (key === "left" || key === "right")))) return { sel: sel, action: null }
  if (sel === 1) return { sel: sel, action: "mute" }
  if (menu === "title") return { sel: sel, action: sel === 0 ? (grown ? "swim" : "swim-fresh") : "anew" }
  return { sel: sel, action: sel === 0 ? "resume" : sel === 2 ? "anew" : "title" }
}

// held: map of key -> action name; pointer: {x, y, down} in 320x180 view px; screen: the fish's view position.
// Pure: the caller clears Input.flickEdge after reading it (the web read() consumed it as a side effect).
function readInput(held, pointer, screen, flickEdge) {
  var ax = (has(held, "right") ? 1 : 0) - (has(held, "left") ? 1 : 0)
  var ay = (has(held, "down") ? 1 : 0) - (has(held, "up") ? 1 : 0)
  var m = Math.hypot(ax, ay)
  if (m > 0) { ax /= m; ay /= m }
  else if (pointer && pointer.down) { var v = pointerVector(screen.x, screen.y, pointer.x, pointer.y); ax = v.ax; ay = v.ay }
  return { ax: ax, ay: ay, flick: !!flickEdge }
}

function has(held, action) { for (var k in held) if (held[k] === action) return true; return false }

// swim toward a point: nothing right at the fish, a gentle pull nearby, full speed from afar
function pointerVector(px, py, qx, qy) {
  var dx = qx - px, dy = qy - py, d = Math.hypot(dx, dy)
  if (!(d > 8)) return { ax: 0, ay: 0 }
  var mag = Math.min(1, (d - 8) / 32)
  return { ax: (dx / d) * mag, ay: (dy / d) * mag }
}
