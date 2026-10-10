import QtQuick

// Which keys are held, the pointer, and a queue of menu presses. The overlay feeds press/release
// (autorepeat ignored) and clears everything when focus goes, so the fish never keeps swimming.
QtObject {
  id: root
  property var held: ({})
  property var queue: []
  property bool flickEdge: false
  property var pointer: ({ x: 0, y: 0, down: false })

  function action(key) {
    switch (key) {
    case Qt.Key_Left: case Qt.Key_A: return "left"
    case Qt.Key_Right: case Qt.Key_D: return "right"
    case Qt.Key_Up: case Qt.Key_W: return "up"
    case Qt.Key_Down: case Qt.Key_S: return "down"
    case Qt.Key_Space: return "flick"
    case Qt.Key_Return: case Qt.Key_Enter: return "confirm"
    case Qt.Key_Escape: return "pause"
    case Qt.Key_M: return "mute"
    }
    return ""
  }
  function press(key) {
    var a = action(key)
    if (!a) return false
    if (!root.held[key]) root.queue.push(a)
    root.held[key] = a
    if (a === "flick") root.flickEdge = true
    return true
  }
  function release(key) { delete root.held[key] }
  function clear() { root.held = ({}); root.queue = []; root.flickEdge = false; root.pointer = { x: 0, y: 0, down: false } }
  function setPointer(x, y, down) { root.pointer = { x: x, y: y, down: down } }
  function requestFlick() { root.flickEdge = true }
  function presses() { var q = root.queue; root.queue = []; return q }
  function isHeld(a) { for (var k in root.held) if (root.held[k] === a) return true; return false }
}
