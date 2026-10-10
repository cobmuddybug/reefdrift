import QtQuick
import Quickshell
import qs.Ui

// A plain fish in the bar: click to open (or close) the game overlay. No custom colouring.
BarWidget {
  id: root
  moduleName: "io.github.cobmuddybug.reefdrift"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈺"
    tooltipText: "Reef Drift"
    horizontalMargin: 7.5
    onPressed: function(mouseButton) {
      if (!root.bar || !root.bar.shell || typeof root.bar.shell.summon !== "function") return
      root.bar.shell.summon(root.moduleName, "{}")
    }
  }
}
