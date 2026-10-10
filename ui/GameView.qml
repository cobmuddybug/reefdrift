import QtQuick
import "atlas.js" as Atlas
import "sprites.js" as Sprites
import "../logic/reef.js" as R
import "../logic/camera.js" as Cam

// The 320x180 reef, drawn from baked images (see dev/tools/bake-sprites.mjs). App calls render() once a
// frame after stepping the sim; nothing here changes the sim. The draw order and constants are the web
// game's render.js. One small Canvas draws the 1px effects (plankton, rings, particles, surface, HUD bar).
Item {
  id: root
  width: 320; height: 180
  clip: true

  property var sim: null            // Reef.sim game state
  property var fxState: null        // Reef.fx state
  property var cam: ({ x: 0, y: 90 })
  property bool hud: true
  property var nowPlaying: null     // { title, composer, t }
  property string message: ""       // big centred text, e.g. FULLY GROWN
  property bool dimmed: false

  readonly property var world: R.Reef.world
  readonly property var species: R.Reef.species.SPECIES
  readonly property real startR: R.Reef.species.START_R
  readonly property real maxR: R.Reef.species.MAX_R

  // per-frame values the canvas needs
  property real _top: 0
  property real _night: 0
  property var _plankton: []
  property var _rings: []
  property var _shimmers: []
  property var _player: null

  component Sp: Item {
    property var rect: null
    visible: rect !== null
    width: rect ? rect[2] : 0; height: rect ? rect[3] : 0
    clip: true
    Image {
      source: Qt.resolvedUrl("../sprites/atlas.png")
      x: parent.rect ? -parent.rect[0] : 0; y: parent.rect ? -parent.rect[1] : 0
      smooth: false; cache: true
    }
  }

  // ---- the sea: four night steps, the two neighbours blended by opacity ----
  property int stepA: 0
  property int stepB: 1
  property real mixB: 0
  property real shaftX: 0
  // Real-valued copies of the camera: QML bindings do not notice in-place changes to the `cam` object, so
  // render() republishes these every frame and the layers bind to them.
  property real camX: 0
  property real camY: 90
  readonly property real seaScroll: root.camX - 160   // what the sea layer's scroll is bound to
  Repeater {
    id: steps
    model: 4
    Item {
      id: layer
      readonly property int s: index
      anchors.fill: parent
      visible: s === root.stepA || (s === root.stepB && root.mixB > 0)
      opacity: s === root.stepB && s !== root.stepA ? root.mixB : 1
      Image { source: Qt.resolvedUrl("../sprites/layers/water-" + layer.s + ".png"); smooth: false; y: -Math.round(root._top) }
      Image { visible: root._top < 300; source: Qt.resolvedUrl("../sprites/layers/shafts-" + layer.s + ".png"); smooth: false; x: -root.shaftX; y: -Math.round(root._top) }
      Image { visible: root._top < 300; source: Qt.resolvedUrl("../sprites/layers/shafts-" + layer.s + ".png"); smooth: false; x: 56 - root.shaftX; y: -Math.round(root._top) }
      Tiled { source: Qt.resolvedUrl("../sprites/layers/far-" + layer.s + ".png"); period: 384; scroll: root.camX * 0.3 - 160; yOffset: -root._top }
      Tiled { source: Qt.resolvedUrl("../sprites/layers/mid-" + layer.s + ".png"); period: 768; scroll: root.camX * 0.6 - 160; yOffset: -root._top }
      Tiled { source: Qt.resolvedUrl("../sprites/layers/sea-" + layer.s + ".png"); period: 1280; scroll: root.seaScroll; yOffset: -root._top }
    }
  }

  // burrow holes
  Repeater {
    id: holeRep
    model: root.sim ? root.sim.world.holes.length : 0
    Item {
      z: 0.5
      Rectangle { x: -4; y: -1; width: 9; height: 4; color: Atlas.PAL.ink }
      Rectangle { x: -3; y: -2; width: 7; height: 1; color: Atlas.PAL.ink }
    }
  }
  Repeater { id: featRep; model: root.sim ? root.sim.world.features.length : 0; delegate: Sp {} }
  Repeater { id: critRep; model: 120; delegate: Sp {} }
  Sp { id: playerSp; z: 120 }

  // 1px effects on top of the sprites
  Canvas {
    id: fxCanvas
    anchors.fill: parent
    z: 150
    smooth: false
    renderTarget: Canvas.Image
    onPaint: root.paintFx(getContext("2d"))
  }
  Sp { id: hudIcon; z: 155 }
  Image {
    id: fade
    z: 160
    smooth: false
    visible: source != ""
    source: ""
  }

  Rectangle {
    id: creditBox
    z: 170
    visible: root.nowPlaying !== null && root.nowPlaying !== undefined && root.nowPlaying.t > 0
    readonly property string line: root.nowPlaying ? (root.nowPlaying.title + "  -  " + root.nowPlaying.composer).toUpperCase() : ""
    readonly property real tw: Math.max(0, line.length * 6 - 1) + 10
    x: Math.round((320 - tw) / 2) - 1; y: 180 - 22 - 1; width: tw + 2; height: 12
    color: Atlas.PAL.ink
    Rectangle { x: 1; y: 1; width: parent.width - 2; height: 10; color: Atlas.PAL.w7 }
    PixelText { y: 3; anchorX: creditBox.width / 2; align: "center"; text: creditBox.line; tone: "w0"; shadow: "" }
  }
  PixelText { z: 170; visible: root.message !== ""; text: root.message; pxScale: 2; align: "center"; anchorX: 160; y: 24; tone: "white"; shadow: "w6" }

  // ---- helpers ----
  function hash(x, y, s) {
    s = s || 0
    var h = (Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(s, 2246822519)) | 0
    h = Math.imul(h ^ (h >> 13), 1274126177)
    return ((h ^ (h >> 16)) >>> 0) / 4294967296
  }
  function frameOf(fx, c, rate) { return Math.floor(fx.t * rate + c.phase) }

  // ---- the frame ----
  function render() {
    var s = root.sim, fx = root.fxState, cam = root.cam
    if (!s || !fx) return
    var p = s.player
    var top = cam.y - 90
    root._top = top
    root.camX = cam.x; root.camY = cam.y
    var sx = function(wx) { return Math.round(160 + root.world.wrapDx(cam.x, wx)) }
    var sy = function(wy) { return Math.round(wy - top) }

    var dk = Cam.darkness(s.time)
    root._night = dk
    var nm = Cam.nightMix(dk)
    root.stepA = nm.s0
    root.stepB = Math.min(3, nm.s0 + 1)
    root.mixB = nm.s0 < 3 ? nm.frac : 0
    root.shaftX = Math.round((fx.t * 3) % 56)

    // holes
    for (var i = 0; i < holeRep.count; ++i) {
      var h = s.world.holes[i], hi = holeRep.itemAt(i)
      if (!hi) continue
      var hx = sx(h.x)
      hi.visible = hx > -10 && hx < 330
      hi.x = hx; hi.y = sy(h.y)
    }

    // scenery
    var frame2 = Math.floor(fx.t * 2) % 2
    for (i = 0; i < featRep.count; ++i) {
      var f = s.world.features[i], fi = featRep.itemAt(i)
      if (!fi) continue
      var fxp = sx(f.x)
      var back = f.kind === "grass" || f.kind === "fan" || f.kind === "rock"
      var fg = f.kind === "grass" && f.size > 13
      var rect = (fxp < -40 || fxp > 360) ? null : Sprites.lookup("coral", f.kind, f.variant, (frame2 + f.variant) % 2, f.size)
      fi.rect = rect
      if (rect) { fi.x = fxp - (rect[2] >> 1); fi.y = sy(f.y) - rect[3] + 2 }
      fi.z = fg ? 140 : (back && !fg) ? 1 : (p.hidden ? 130 : 2)
    }

    // creatures: biggest first, so little ones swim in front
    var vis = []
    var plankton = [], rings = [], shimmers = []
    for (i = 0; i < s.creatures.length; ++i) {
      var c = s.creatures[i], cx = sx(c.x)
      if (!(cx > -80 && cx < 400 && c.y > top - 80 && c.y < top + 260)) continue
      if (c.sp === "plankton") { plankton.push(c); continue }
      vis.push(c)
    }
    vis.sort(function(a, b) { return b.r - a.r })
    for (i = 0; i < critRep.count; ++i) {
      var it = critRep.itemAt(i)
      if (!it) continue
      if (i >= vis.length) { it.rect = null; continue }
      var cr = vis[i], sp = root.species[cr.sp], x = sx(cr.x), y = sy(cr.y)
      var fr = cr.sp === "manta" ? frameOf(fx, cr, 2.4) % 4 : frameOf(fx, cr, 4) % 2
      var r2 = Sprites.lookup("c", cr.sp, cr.r, fr, cr.face < 0 ? -1 : 1)
      var bob = sp.behaviour === "bob" ? Math.round(Math.sin(fx.t * 1.5 + cr.phase)) : 0
      it.rect = r2
      it.z = 10 + i
      if (r2) {
        it.x = x - (r2[2] >> 1); it.y = y - (r2[3] >> 1) + bob
        var cls = R.Reef.species.classify(p.r, cr.r, sp)
        var near = Math.hypot(root.world.wrapDx(p.x, cr.x), cr.y - p.y) < 130
        if (cls === "threat" && near) rings.push({ x: x, y: y, rad: Math.round(cr.r * 1.8 + 3 + Math.sin(fx.t * 2.2) * 2) })
        else if (cls === "edible" && near && Math.sin(fx.t * 2.7 + cr.phase * 3) > 0.93)
          shimmers.push({ x: x + Math.round((Math.sin(cr.phase * 9) * r2[2]) / 3), y: y - (r2[3] >> 2) })
      }
    }
    root._plankton = plankton.map(function(q) { return { x: sx(q.x), y: sy(q.y), phase: q.phase } })
    root._rings = rings
    root._shimmers = shimmers

    // the player
    var speed = Math.hypot(p.vx, p.vy)
    var pf = Math.floor(fx.t * (2 + speed / 14)) % 2
    var pr = Sprites.lookup("p", null, p.r, pf, p.face)
    var pbob = Math.round(Math.sin(fx.t * 1.6))
    var wob = p.dizzy > 0 ? Math.round(Math.sin(fx.t * 14)) : 0
    playerSp.rect = pr
    if (pr) {
      playerSp.x = sx(p.x) - (pr[2] >> 1) + wob
      playerSp.y = sy(p.y) - (pr[3] >> 1) + pbob
      root._player = { x: playerSp.x, y: playerSp.y, w: pr[2], h: pr[3], cx: sx(p.x) }
    }

    // scatter fade
    var fd = s.fade, lvl = 0
    if (fd.phase !== "none") {
      var k = fd.phase === "out" ? Math.min(1, fd.t / 0.9) : 1 - Math.min(1, fd.t / 1.2)
      lvl = Math.round(k * 16)
    }
    fade.source = lvl > 0 ? Qt.resolvedUrl("../sprites/fade/" + lvl + ".png") : ""

    // growth bar icon
    var showHud = root.hud && fx.hudT <= 5
    var ic = showHud ? Sprites.lookup("p", null, root.startR, 0, 1) : null
    hudIcon.rect = ic
    if (ic) { hudIcon.x = 8 - 1; hudIcon.y = 180 - 14 - ic[3] - 2 }

    fxCanvas.requestPaint()
  }

  function paintFx(ctx) {
    var s = root.sim, fx = root.fxState
    ctx.clearRect(0, 0, 320, 180)
    if (!s || !fx) return
    var PAL = Atlas.PAL, p = s.player, top = root._top, cam = root.cam, night = root._night
    var sx = function(wx) { return Math.round(160 + root.world.wrapDx(cam.x, wx)) }
    var sy = function(wy) { return Math.round(wy - top) }
    var px = function(col, x, y) { ctx.fillStyle = col; ctx.fillRect(x, y, 1, 1) }
    var i, a

    // plankton, glowing at night
    var pl = root._plankton
    for (i = 0; i < pl.length; ++i) {
      var q = pl[i], tw = Math.sin(fx.t * 2 + q.phase * 5) > 0.2
      px(night > 0.5 ? PAL.teal : PAL.w0, q.x, q.y)
      if (night > 0.45 && tw) {
        px(PAL.white, q.x, q.y)
        px(PAL.teal, q.x - 1, q.y); px(PAL.teal, q.x + 1, q.y); px(PAL.teal, q.x, q.y - 1); px(PAL.teal, q.x, q.y + 1)
      }
    }
    // threat rings and food shimmer
    ctx.fillStyle = PAL.w7
    for (i = 0; i < root._rings.length; ++i) {
      var rg = root._rings[i]
      for (a = 0; a < 6.28; a += 0.18) ctx.fillRect(Math.round(rg.x + Math.cos(a) * rg.rad * 1.2), Math.round(rg.y + Math.sin(a) * rg.rad * 0.8), 1, 1)
    }
    ctx.fillStyle = PAL.white
    for (i = 0; i < root._shimmers.length; ++i) ctx.fillRect(root._shimmers[i].x, root._shimmers[i].y, 1, 1)

    // the player: a shimmer while safe after a scatter, dizzy stars
    var pp = root._player
    if (pp) {
      if (p.inv > 0 && Math.floor(fx.t * 8) % 2 === 0) {
        ctx.fillStyle = PAL.white
        for (i = 0; i < 4; ++i) ctx.fillRect(pp.x + Math.round(root.hash(i, Math.floor(fx.t * 8)) * pp.w), pp.y + Math.round(root.hash(i, 5) * pp.h), 1, 1)
      }
      if (p.dizzy > 0) {
        ctx.fillStyle = PAL.yellow
        for (i = 0; i < 3; ++i) { a = fx.t * 5 + i * 2.1; ctx.fillRect(Math.round(pp.cx + Math.cos(a) * 6), Math.round(pp.y - 3 + Math.sin(a) * 2), 1, 1) }
      }
    }

    // particles
    for (i = 0; i < fx.parts.length; ++i) {
      var pt = fx.parts[i], x = sx(pt.x), y = sy(pt.y)
      if (x < -8 || x > 328 || y < -8 || y > 188) continue
      if (pt.kind === "bubble") {
        ctx.fillStyle = PAL.white
        if (pt.r === 2) { ctx.fillRect(x, y, 2, 1); ctx.fillRect(x, y + 1, 1, 1); ctx.fillStyle = PAL.w0; ctx.fillRect(x + 1, y + 1, 1, 1) }
        else ctx.fillRect(x, y, 1, 1)
      } else if (pt.kind === "glint") {
        ctx.fillStyle = PAL.white
        ctx.fillRect(x, y, 1, 1); ctx.fillRect(x - 1, y, 1, 1); ctx.fillRect(x + 1, y, 1, 1); ctx.fillRect(x, y - 1, 1, 1); ctx.fillRect(x, y + 1, 1, 1)
      } else if (pt.kind === "ripple") {
        var k = 1 - pt.life / pt.max, rad = pt.r + k * 26
        ctx.fillStyle = PAL.w7
        for (a = 0; a < 6.28; a += 0.16) ctx.fillRect(Math.round(x + Math.cos(a) * rad), Math.round(y + Math.sin(a) * rad * 0.6), 1, 1)
      } else if (pt.kind === "crumb") { ctx.fillStyle = PAL.cream; ctx.fillRect(x, y, 1, 1) }
      else if (pt.kind === "haze") { ctx.fillStyle = pt.life % 1 > 0.5 ? PAL.pink : PAL.white; ctx.fillRect(x, y, 1, 1) }
    }

    // the surface
    if (top <= 12) {
      var base = -Math.round(top)
      for (var xx = 0; xx < 320; ++xx) {
        var sy2 = base + 1 + Math.round(Math.sin(xx * 0.16 + fx.t * 1.6) * 1.1)
        px(PAL.white, xx, sy2); px(PAL.w0, xx, sy2 + 1)
        if ((xx + Math.floor(fx.t * 4)) % 9 === 0) px(PAL.white, xx, sy2 + 3)
      }
    }

    // growth bar: appears when you grow and fades away
    if (root.hud && fx.hudT <= 5) {
      var kk = (p.r - root.startR) / (root.maxR - root.startR), bx = 8, by = 180 - 14, bw = 44
      ctx.fillStyle = PAL.ink; ctx.fillRect(bx - 1, by - 1, bw + 2, 6)
      ctx.fillStyle = PAL.w6; ctx.fillRect(bx, by, bw, 4)
      ctx.fillStyle = PAL.teal; ctx.fillRect(bx, by, Math.round(bw * kk), 4)
      ctx.fillStyle = PAL.w0; ctx.fillRect(bx, by, Math.round(bw * kk), 1)
    }
  }
}
