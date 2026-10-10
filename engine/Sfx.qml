import QtQuick
import QtMultimedia
import "../ui/sounds.js" as Snd

// Plays the baked effects in sounds/sfx. Effects are made on first use; a sound that repeats faster than
// its gap is dropped so a flurry never turns into a buzz.
Item {
  id: root
  property bool muted: false
  property var last: ({})
  property var effects: ({})
  Component { id: comp; SoundEffect { volume: 1.0 } }

  function file(name, arg) {
    if (name === "eat") return Snd.eatFile(arg || 3)
    if (name === "chime") return Snd.CHIMES[Math.floor(Math.random() * Snd.CHIMES.length)]
    return Snd.SFX[name] || ""
  }
  function play(name, arg) {
    if (root.muted) return
    var f = root.file(name, arg)
    if (!f) return
    var now = Date.now()
    if (now - (root.last[name] || 0) < (name === "eat" ? 20 : 40)) return
    root.last[name] = now
    var e = root.effects[f]
    if (!e) { e = comp.createObject(root, { source: Qt.resolvedUrl("../sounds/" + f) }); root.effects[f] = e }
    if (e) e.play()
  }
}
