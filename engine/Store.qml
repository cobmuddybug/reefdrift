import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/reef.js" as R

// ~/.local/share/reefdrift/save.json (REEFDRIFT_HOME in tests): { r, peak, time, mute }.
// A missing or broken file reads as the defaults; nothing here ever throws.
Item {
  id: root
  readonly property string dataDir: Quickshell.env("REEFDRIFT_HOME") || ((Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/reefdrift")
  property var profile: R.Reef.save.load({ getItem: function() { return null } })
  property bool ready: false

  function saveProfile(p) {
    root.profile = p
    R.Reef.save.save(p, { setItem: function(k, v) { file.setText(v + "\n") } })
  }

  FileView {
    id: file
    path: root.dataDir + "/save.json"
    atomicWrites: true; printErrors: false
    blockWrites: true   // a save made as the overlay closes must finish before anything is torn down
    onLoaded: { var raw = text(); root.profile = R.Reef.save.load({ getItem: function() { return raw } }) }
  }
  Process {
    id: ensureDir
    command: ["mkdir", "-p", "--", root.dataDir]
    onExited: { file.reload(); root.ready = true }
  }
  Component.onCompleted: ensureDir.running = true
}
