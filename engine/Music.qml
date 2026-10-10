import QtQuick
import QtMultimedia
import "../ui/sounds.js" as Snd
import "../logic/reef.js" as R

// The ocean wash (three baked loops crossfaded by depth and night) and the piano: one piece at a time,
// chosen by mood, with long silences between. Mirrors musicTick() in the web game's audio.js.
Item {
  id: root
  property bool muted: false
  property bool active: false
  property string mood: "mid"
  property real washFreq: 700
  property string curId: ""
  signal trackStarted(var info)

  readonly property int minPlay: 45000
  readonly property int fadeMs: 4000
  readonly property int leadIn: 1500
  readonly property bool running: active && !muted

  // idle | leadin | playing | fading
  property string phase: "idle"
  property real gapUntil: 0
  property real startedAt: 0
  property real fadeEnd: 0
  property string lastId: ""

  function setMood(depth, night, fullgrown) {
    root.mood = R.Reef.music.moodOf({ depth: depth, dark: night, fullgrown: !!fullgrown }, root.mood)
    root.washFreq = 700 - 450 * Math.max(0, Math.min(1, depth)) - 120 * Math.max(0, Math.min(1, night))
  }

  // equal-power weights between the two baked loops that bracket the target filter frequency
  readonly property var weights: {
    var f = Math.max(130, Math.min(700, washFreq)), w = { bright: 0, mid: 0, deep: 0 }
    if (f >= 400) { var t = (f - 400) / 300; w.mid = Math.cos(t * Math.PI / 2); w.bright = Math.sin(t * Math.PI / 2) }
    else { var u = (f - 130) / 270; w.deep = Math.cos(u * Math.PI / 2); w.mid = Math.sin(u * Math.PI / 2) }
    return w
  }

  Component {
    id: washComp
    Item {
      property string key
      property alias player: p
      MediaPlayer {
        id: p
        source: Qt.resolvedUrl("../sounds/" + Snd.WASH[key])
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: root.running ? root.weights[key] : 0 }
      }
    }
  }
  property var washes: []
  Component.onCompleted: {
    var list = []
    for (var k in Snd.WASH) list.push(washComp.createObject(root, { key: k }))
    root.washes = list
  }
  onRunningChanged: {
    for (var i = 0; i < washes.length; ++i) { if (running) washes[i].player.play(); else washes[i].player.stop() }
    if (!running) endNow(0)
  }

  MediaPlayer {
    id: piece
    audioOutput: AudioOutput { id: pieceOut; volume: 1 }
    onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && (root.phase === "playing" || root.phase === "fading") && mediaStatus === MediaPlayer.EndOfMedia) root.endNow(8000 + Math.random() * 8000)
  }
  NumberAnimation { id: ramp; target: pieceOut; property: "volume" }

  function endNow(gapMs) {
    piece.stop()
    ramp.stop()
    root.phase = "idle"; root.curId = ""
    root.gapUntil = Date.now() + gapMs
  }
  function fadeTo(v, ms) { ramp.stop(); ramp.to = v; ramp.duration = ms; ramp.from = pieceOut.volume; ramp.start() }

  function startPiece() {
    var id = R.Reef.music.pickTrack(root.mood, root.lastId, Math.random)
    root.lastId = id; root.curId = id
    var p = R.Reef.music.prepare(id)
    piece.source = Qt.resolvedUrl("../sounds/" + Snd.TRACKS[id])
    pieceOut.volume = 0
    root.phase = "leadin"
    root.startedAt = Date.now()
    leadTimer.restart()
    root.trackStarted({ id: id, title: p.title, composer: p.composer })
  }
  Timer {
    id: leadTimer
    interval: root.leadIn
    onTriggered: { if (root.phase === "leadin") { root.phase = "playing"; piece.play(); root.fadeTo(1, 3000) } }
  }

  Timer {
    interval: 250; repeat: true; running: root.running
    onTriggered: {
      var now = Date.now()
      if (root.phase === "idle") { if (now >= root.gapUntil) root.startPiece(); return }
      if (root.phase === "fading") { if (now >= root.fadeEnd) root.endNow(2000 + Math.random() * 2000); return }
      if (root.phase === "playing" && now - root.startedAt > root.minPlay && (R.Reef.music.MOODS[root.mood] || R.Reef.music.MOODS.mid).indexOf(root.curId) < 0) {
        root.phase = "fading"; root.fadeEnd = now + root.fadeMs
        root.fadeTo(0, root.fadeMs)
      }
    }
  }
}
