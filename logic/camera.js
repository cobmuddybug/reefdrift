.pragma library
.import "reef.js" as R

var VIEW_W = 320, VIEW_H = 180

function darkness(time) { return 0.5 - 0.5 * Math.cos(2 * Math.PI * (time - 0.25)) }
function fitScale(w, h) { return Math.max(1, Math.floor(Math.min(w / VIEW_W, h / VIEW_H) || 1)) }
function nightMix(dk) {
  var k = dk * 3, s0 = Math.min(3, Math.floor(k))
  return { s0: s0, frac: k - s0 }
}
function clampY(y) { return Math.max(VIEW_H / 2, Math.min(R.Reef.world.WORLD_H - VIEW_H / 2, y)) }
function makeCamera(player) { return { x: player.x, y: clampY(player.y) } }
function updateCamera(cam, player, dt) {
  var k = 1 - Math.exp(-3.2 * dt), W = R.Reef.world
  var tx = player.x + player.face * 22, ty = clampY(player.y)
  cam.x = W.wrapX(cam.x + W.wrapDx(cam.x, tx) * k)
  cam.y += (ty - cam.y) * k
}
