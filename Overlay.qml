import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "ui" as Ui

// The game surface: a full-screen layer with the game in a 16:9 card. One instance per shell
// session; closing pauses a swim rather than throwing anything away.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: (manifest && manifest.id) || "io.github.cobmuddybug.reefdrift"
  property bool opened: false

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keys.forceActiveFocus() })
  }
  function close() {
    game.clearHeld()
    root.opened = false
  }
  function dismiss() {
    close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }
  function toggle() { root.opened ? root.dismiss() : root.open("{}") }

  function keyNamed(name) { return Qt["Key_" + name] }

  // Scripting and testing from outside: `omarchy-shell io.github.cobmuddybug.reefdrift <fn> <args>`.
  IpcHandler {
    target: "io.github.cobmuddybug.reefdrift"
    function open(): void { root.open("{}") }
    function close(): void { root.dismiss() }
    function toggle(): void { root.toggle() }
    function tap(name: string): void { var k = root.keyNamed(name); if (k === undefined) return; game.keyPressed(k, name.length === 1 ? name.toLowerCase() : "", 0, false); game.keyReleased(k, false) }
    function hold(name: string): void { var k = root.keyNamed(name); if (k !== undefined) game.keyPressed(k, "", 0, false) }
    function release(name: string): void { var k = root.keyNamed(name); if (k !== undefined) game.keyReleased(k, false) }
    function go(screen: string): void { game.go(screen) }
    function shot(path: string): void { game.grabToImage(function(r) { r.saveToFile(path) }) }
    function state(): string {
      var s = game.status()
      s.opened = root.opened
      return JSON.stringify(s)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "reefdrift"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: "#d80e1c3d" }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Rectangle {
      id: card
      readonly property real maxW: Math.min(1760, panel.width - 64)
      readonly property real maxH: Math.min(990, panel.height - 64)
      width: Math.min(maxW, maxH * 16 / 9)
      height: width * 9 / 16
      anchors.centerIn: parent
      color: "#0e1c3d"
      border.width: 2
      border.color: "#215a97"

      MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

      Item {
        id: keys
        anchors.fill: parent
        anchors.margins: 2
        clip: true
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(e) { if (game.keyPressed(e.key, e.text, e.modifiers, e.isAutoRepeat)) e.accepted = true }
        Keys.onReleased: function(e) { game.keyReleased(e.key, e.isAutoRepeat); e.accepted = true }
        onActiveFocusChanged: if (!activeFocus) game.clearHeld()

        Ui.App {
          id: game
          anchors.fill: parent
          shown: root.opened
          onRequestClose: root.dismiss()
          onWantFocus: keys.forceActiveFocus()
        }
      }
    }
  }

  onOpenedChanged: if (opened) Qt.callLater(function() { keys.forceActiveFocus() })
}
