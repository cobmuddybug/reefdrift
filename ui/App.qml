import QtQuick
import "../engine" as Engine
import "../logic/reef.js" as R
import "../logic/camera.js" as Cam
import "../logic/flow.js" as Flow
import "atlas.js" as Atlas

// The whole game as one item: title, swim and pause (the web game's scenes.js), the frame loop, input,
// save and sound. The overlay puts it in a layer-shell window; the dev harness in a plain window.
Item {
  id: app
  property string screen: "title"      // title | swim | pause
  property bool shown: true
  signal requestClose()
  signal wantFocus()

  readonly property var reef: R.Reef
  readonly property var profile: store.profile
  readonly property bool grown: profile.r > reef.species.START_R + 0.01

  Engine.Store { id: store }
  Engine.Input { id: input }
  Engine.Sfx { id: sfx; muted: app.profile.mute }
  Engine.Music {
    id: music
    muted: app.profile.mute
    active: app.shown
    onTrackStarted: function(info) { app.credit = { title: info.title, composer: info.composer, t: 8 } }
  }

  property var fx: reef.fx.makeFx()
  property var sim: null               // the game being played (swim, pause) or the title's demo
  property var cam: ({ x: 0, y: 90 })
  property var credit: null
  property int sel: 0
  property real t: 0
  property real saveT: 0
  property real moodT: 0
  property real whaleT: 60
  property real msgT: 0
  property int eats: 0
  property int scatters: 0
  property bool botDrive: false
  property int closeRequests: 0

  // ---------------- profile ----------------
  function persist(extra) {
    var p = app.profile, o = { r: p.r, peak: p.peak, time: p.time, mute: p.mute }
    for (var k in extra) o[k] = extra[k]
    store.saveProfile(o)
  }
  function saveNow() {
    if (!app.sim || app.screen === "title") return
    var pl = app.sim.player
    app.persist({ r: pl.r, peak: pl.peak, time: app.sim.time })
  }
  function toggleMute() { app.persist({ mute: !app.profile.mute }) }
  function beginAnew() {
    var d = reef.save.DEFAULTS
    store.saveProfile({ r: d.r, peak: d.peak, time: app.profile.time, mute: app.profile.mute })
  }

  // ---------------- scenes ----------------
  function enterTitle() {
    var demo = reef.sim.createGame({ seed: 1, r: 7, time: app.profile.time })
    demo.player.x = 800; demo.player.y = 70; demo.player.inv = 99
    app.fx = reef.fx.makeFx()
    app.sim = demo
    app.cam = Cam.makeCamera(demo.player)
    for (var i = 0; i < 60; ++i) reef.sim.step(demo, { ax: 0, ay: 0 }, 1 / 30)
    app.sel = 0; app.t = 0; app.screen = "title"
    input.clear()
  }
  function enterSwim(fresh) {
    if (fresh) app.persist({ r: reef.species.START_R, peak: reef.species.START_R })
    app.startGame(app.profile.r, app.profile.peak, app.profile.time)
  }
  function startGame(r, peak, time) {
    var g = reef.sim.createGame({ seed: 1, r: r, peak: peak, time: time })
    g.fade = { phase: "in", t: 0 }
    app.fx = reef.fx.makeFx()
    app.fx.hudT = 0
    app.sim = g
    app.cam = Cam.makeCamera(g.player)
    app.saveT = 0; app.moodT = 0; app.whaleT = 40 + Math.random() * 40; app.msgT = 0
    app.eats = 0; app.scatters = 0
    input.clear()
    app.screen = "swim"
  }
  // harness/testing: a swim at radius r and time of day t, settled for a few seconds
  function scene(r, t) {
    app.startGame(r, r, t)
    app.sim.fade = { phase: "none", t: 0 }
    for (var i = 0; i < 240; ++i) reef.sim.step(app.sim, reef.bot.botInput(app.sim), 1 / 60)
    app.cam = Cam.makeCamera(app.sim.player)
  }
  // harness/testing: run the game for `secs` of game time without drawing, the bot at the controls
  function ff(secs) {
    var was = app.botDrive
    app.botDrive = true
    for (var i = 0; i < secs * 30; ++i) app.update(1 / 30)
    app.botDrive = was
  }
  function go(where) {
    if (where === "title") enterTitle()
    else if (where === "swim") enterSwim(false)
    else if (where === "pause") { if (app.screen === "swim") { saveNow(); app.screen = "pause"; app.sel = 0 } }
    input.clear()
  }

  function doAction(action) {
    if (action === "mute") toggleMute()
    else if (action === "swim") { sfx.play("confirm"); enterSwim(false) }
    else if (action === "swim-fresh") { sfx.play("confirm"); enterSwim(true) }
    else if (action === "anew") { sfx.play("confirm"); beginAnew(); enterSwim(true) }
    else if (action === "resume") { input.clear(); app.screen = "swim" }
    else if (action === "title") enterTitle()
  }
  function menuKey(menu, k) {
    var r = Flow.menuStep(menu, app.sel, k, menu === "pause" ? true : app.grown)
    if (r.sel !== app.sel) sfx.play("menu")
    app.sel = r.sel
    if (r.action) doAction(r.action)
  }

  // ---------------- the frame ----------------
  function update(dt) {
    var fxState = app.fx, W = reef.world
    var presses = input.presses()
    if (presses.indexOf("mute") >= 0) { toggleMute(); presses = presses.filter(function(k) { return k !== "mute" }) }
    if (app.credit) app.credit = app.credit.t > 0 ? { title: app.credit.title, composer: app.credit.composer, t: app.credit.t - dt } : null

    if (app.screen === "title") {
      var d = app.sim
      app.t += dt
      d.player.r = 7; d.player.inv = 99
      reef.sim.step(d, reef.bot.botInput(d), dt)
      reef.fx.update(fxState, dt); reef.fx.handleEvents(fxState, d.events, d)
      app.cam.x = W.wrapX(app.cam.x + 9 * dt)
      app.cam.y += (d.player.y - app.cam.y) * Math.min(1, dt)
      app.cam.y = Cam.clampY(app.cam.y)
      for (var i = 0; i < presses.length; ++i) {
        if (presses[i] === "pause") { app.closeRequests++; app.requestClose(); continue }   // Esc on the title closes the overlay
        menuKey("title", presses[i]); if (app.screen !== "title") return
      }
      return
    }
    if (app.screen === "pause") {
      for (var j = 0; j < presses.length; ++j) { menuKey("pause", presses[j]); if (app.screen !== "pause") return }
      return
    }
    // swim
    for (var q = 0; q < presses.length; ++q) if (presses[q] === "pause") { saveNow(); app.screen = "pause"; app.sel = 0; return }
    var s = app.sim, p = s.player
    var scr = { x: 160 + W.wrapDx(app.cam.x, p.x), y: p.y - (app.cam.y - 90) }
    var inp = app.botDrive ? reef.bot.botInput(s) : Flow.readInput(input.held, input.pointer, scr, input.flickEdge)
    input.flickEdge = false
    reef.sim.step(s, inp, dt)
    for (var e = 0; e < s.events.length; ++e) {
      var ev = s.events[e]
      if (ev.type === "eat") app.eats++
      if (ev.type === "scatter") app.scatters++
      if (ev.type === "fullgrown") app.msgT = 7
      if (ev.type === "respawn") app.cam = Cam.makeCamera(p)   // the screen is dark: snap to the shelter
    }
    reef.fx.update(fxState, dt)
    reef.fx.handleEvents(fxState, s.events, s, function(n, a) { sfx.play(n, a) })
    Cam.updateCamera(app.cam, p, dt)
    app.msgT = Math.max(0, app.msgT - dt)
    app.saveT += dt; if (app.saveT > 5) { app.saveT = 0; saveNow() }
    app.moodT -= dt
    if (app.moodT <= 0) { app.moodT = 0.5; music.setMood(p.y / W.WORLD_H, Cam.darkness(s.time), s.fullgrown) }
    app.whaleT -= dt
    if (app.whaleT <= 0) { app.whaleT = 50 + Math.random() * 60; if (p.y > W.WORLD_H * 0.6) sfx.play("whale") }
  }

  FrameAnimation {
    running: app.shown && app.sim !== null
    onTriggered: { app.update(Math.min(0.05, frameTime)); view.render() }
  }
  onShownChanged: {
    if (!shown) { input.clear(); if (app.screen === "swim") { saveNow(); app.screen = "pause"; app.sel = 0 } }
  }
  Component.onCompleted: enterTitle()

  function status() {
    var s = app.sim, p = s ? s.player : null
    return {
      screen: app.screen, ready: store.ready, r: p && app.screen !== "title" ? p.r : app.profile.r, peak: p ? p.peak : app.profile.peak,
      time: s && app.screen !== "title" ? s.time : app.profile.time, depth: p ? p.y / reef.world.WORLD_H : 0,
      x: p ? p.x : 0, y: p ? p.y : 0, creatures: s ? s.creatures.length : 0, eats: app.eats, scatters: app.scatters,
      fade: s ? s.fade.phase : "none", hidden: p ? p.hidden : false, muted: app.profile.mute, track: music.curId, mood: music.mood,
      held: Object.keys(input.held).length, camX: app.cam.x, seaScroll: view.seaScroll, closeRequests: app.closeRequests
    }
  }
  function keyPressed(key, text, mods, auto) {
    if (auto) return input.action(key) !== ""
    return input.press(key)
  }
  function keyReleased(key, auto) { if (!auto) input.release(key) }
  function clearHeld() { input.clear() }

  // ---------------- drawing ----------------
  component Panel: Item {
    Rectangle { anchors.fill: parent; color: Atlas.PAL.ink }
    Rectangle { x: 1; y: 1; width: parent.width - 2; height: parent.height - 2; color: Atlas.PAL.w6 }
    Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: Atlas.PAL.w4 }
  }
  component Rows: Item {
    id: rows
    property var items: []
    property int selected: 0
    property real rowX: 0
    Repeater {
      model: rows.items
      PixelText {
        anchorX: rows.rowX; y: index * 11
        text: (index === rows.selected ? ">" : " ") + " " + modelData
        tone: index === rows.selected ? "yellow" : "white"; shadow: ""
      }
    }
  }

  Rectangle { anchors.fill: parent; color: "#000000" }
  Item {
    id: stage
    readonly property int k: Cam.fitScale(app.width, app.height)
    width: 320 * k; height: 180 * k
    anchors.centerIn: parent
    clip: true

    GameView {
      id: view
      scale: stage.k
      transformOrigin: Item.TopLeft
      sim: app.sim; fxState: app.fx; cam: app.cam
      hud: app.screen !== "title"
      nowPlaying: app.credit
      message: app.screen !== "title" && app.msgT > 0 && app.msgT < 6.5 ? "FULLY GROWN" : ""
    }

    Item {
      width: 320; height: 180
      scale: stage.k; transformOrigin: Item.TopLeft

      // title
      Item {
        anchors.fill: parent
        visible: app.screen === "title"
        Panel { x: 56; y: 22; width: 208; height: 46 }
        PixelText { anchorX: 160; align: "center"; y: 29 + Math.round(Math.sin(app.t * 1.4)); text: "REEF DRIFT"; pxScale: 3; shadow: "w5" }
        PixelText { anchorX: 160; align: "center"; y: 55; text: "A QUIET SWIM"; tone: "w0"; shadow: "" }
        Panel { x: 108; y: 112; width: 104; height: 12 + titleRows.items.length * 11 }
        Rows { id: titleRows; y: 118; rowX: 116; selected: app.sel; items: Flow.titleItems(app.grown, app.profile.mute) }
        Rectangle { y: 166; width: 320; height: 14; color: Atlas.PAL.w7 }
        Rectangle { y: 166; width: 320; height: 1; color: Atlas.PAL.w5 }
        PixelText { anchorX: 160; align: "center"; y: 170; text: "ARROWS OR MOUSE TO SWIM   SPACE TO FLICK"; tone: "w0"; shadow: "" }
      }
      // pause
      Item {
        anchors.fill: parent
        visible: app.screen === "pause"
        Panel { x: 100; y: 50; width: 120; height: 80 }
        PixelText { anchorX: 160; align: "center"; y: 58; text: "PAUSED"; pxScale: 2; shadow: "w4" }
        Rows { y: 80; rowX: 110; selected: app.sel; items: Flow.pauseItems(app.profile.mute) }
      }
    }

    // pointer steering: hold the mouse and the fish swims toward it; right-click flicks
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: function(e) {
        app.wantFocus()
        if (e.button === Qt.RightButton) { input.requestFlick(); return }
        input.setPointer(e.x / stage.k, e.y / stage.k, true)
      }
      onPositionChanged: function(e) { if (pressed && (pressedButtons & Qt.LeftButton)) input.setPointer(e.x / stage.k, e.y / stage.k, true) }
      onReleased: function(e) { input.setPointer(e.x / stage.k, e.y / stage.k, false) }
    }
  }
}
