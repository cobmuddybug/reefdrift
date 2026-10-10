import QtQuick
import QtQuick.Window
import Quickshell

// Runs the game in a plain window, outside the shell: `make dev`.
// Headless checks: REEFDRIFT_SCRIPT is a comma list of steps, one per tick (40 ms):
//   w / w20         wait one / twenty ticks
//   k:Right         tap a key (press, release next tick; k:alt+W for a modified key)     d:Right / u:Right  hold / let go
//   ff:SECS         run SECS of game time at once with the bot swimming
//   blur            what losing focus does (clear held keys)
//   scene:R:T       a swim at radius R, time of day T
//   go:title        switch screen                             shot:/path.png  save a screenshot
//   status          print state                               quit
// Key names are Qt.Key_* without the prefix (Right, Space, Escape, Return, M...).
Window {
  id: win
  visible: true
  width: Number(Quickshell.env("REEFDRIFT_W") || 1280)
  height: Number(Quickshell.env("REEFDRIFT_H") || 720)
  color: "#000000"
  title: "Reef Drift dev harness"

  // Loaded by path: Quickshell won't statically import files outside dev/harness.
  readonly property string root: Quickshell.env("REEFDRIFT_ROOT") || Qt.resolvedUrl("../..").toString().replace("file://", "")
  property Item app: loader.item
  Loader {
    id: loader
    anchors.fill: parent
    focus: true
    source: "file://" + win.root + "/ui/App.qml"
    Keys.onPressed: function(e) { if (win.app && win.app.keyPressed(e.key, e.text, e.modifiers, e.isAutoRepeat)) e.accepted = true }
    Keys.onReleased: function(e) { if (win.app) win.app.keyReleased(e.key, e.isAutoRepeat) }
  }
  Connections {
    target: win.app
    function onRequestClose() { if (!win.script.length) Qt.quit() }
    function onWantFocus() { loader.forceActiveFocus() }
  }

  readonly property var script: (Quickshell.env("REEFDRIFT_SCRIPT") || "").split(",").filter(function(t) { return t.length > 0 })
  property int pos: 0
  property int wait: 0
  property var tapRelease: []

  function keyOf(name) { return Qt["Key_" + name] }

  Timer {
    interval: 40; repeat: true
    running: win.script.length > 0
    property int warm: 15
    onTriggered: {
      if (warm-- > 0 || !win.app) return
      var app = win.app
      win.tapRelease.forEach(function(k) { app.keyReleased(k, false) }); win.tapRelease = []
      if (win.wait > 0) { win.wait--; return }
      if (win.pos >= win.script.length) return
      var s = win.script[win.pos++]
      var m = s.match(/^w(\d*)$/)
      if (m) { win.wait = m[1] ? Number(m[1]) - 1 : 0; return }
      var i = s.indexOf(":"), op = i < 0 ? s : s.slice(0, i), arg = i < 0 ? "" : s.slice(i + 1)
      if (op === "k") { var mods = 0, name = arg; if (name.indexOf("alt+") === 0) { mods = Qt.AltModifier; name = name.slice(4) } var k = keyOf(name); if (k !== undefined) { app.keyPressed(k, name.length === 1 ? name.toLowerCase() : "", mods, false); win.tapRelease.push(k) } }
      else if (op === "d") app.keyPressed(keyOf(arg), "", 0, false)
      else if (op === "u") app.keyReleased(keyOf(arg), false)
      else if (op === "go") app.go(arg)
      else if (op === "ff") app.ff(Number(arg))
      else if (op === "blur") app.clearHeld()
      else if (op === "scene") { var a = arg.split(":"); app.scene(Number(a[0]), Number(a[1])) }
      else if (op === "shot") { var path = arg; win.contentItem.grabToImage(function(r) { r.saveToFile(path); console.log("REEFDRIFT_SHOT " + path) }) }
      else if (op === "status") console.log("REEFDRIFT_STATUS " + JSON.stringify(app.status()))
      else if (op === "quit") Qt.quit()
    }
  }
}
