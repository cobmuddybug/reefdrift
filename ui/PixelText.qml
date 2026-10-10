import QtQuick
import "atlas.js" as Atlas

// The web game's 5x7 bitmap font. Callers set `anchorX` (and `y`), never `x`: x is derived from
// anchorX and `align`.
Item {
  id: root
  property string text: ""
  property string tone: "white"
  property string shadow: "ink"      // palette key, or "" for none
  property int pxScale: 1
  property string align: "left"
  property real anchorX: 0
  readonly property string up: text.toUpperCase()
  implicitWidth: Math.max(0, up.length * Atlas.GLYPH_CELL - 1) * pxScale
  implicitHeight: 7 * pxScale
  width: implicitWidth; height: implicitHeight
  x: align === "center" ? Math.round(anchorX - implicitWidth / 2) : align === "right" ? Math.round(anchorX - implicitWidth) : Math.round(anchorX)

  component Run: Item {
    property string tone
    Repeater {
      model: root.up.length
      Item {
        readonly property int gi: Atlas.GLYPHS.indexOf(root.up[index])
        visible: gi >= 0 && root.up[index] !== " "
        x: index * Atlas.GLYPH_CELL * root.pxScale; width: 5 * root.pxScale; height: 7 * root.pxScale; clip: true
        Image {
          source: tone !== "" ? Qt.resolvedUrl("../sprites/font/" + tone + ".png") : ""
          smooth: false
          x: -parent.gi * Atlas.GLYPH_CELL * root.pxScale
          width: Atlas.GLYPHS.length * Atlas.GLYPH_CELL * root.pxScale; height: 7 * root.pxScale
        }
      }
    }
  }
  // the web draws the shadow three times: (+s,+s), (+s,0), (0,+s)
  Run { visible: root.shadow !== ""; tone: root.shadow; x: root.pxScale; y: root.pxScale }
  Run { visible: root.shadow !== ""; tone: root.shadow; x: root.pxScale }
  Run { visible: root.shadow !== ""; tone: root.shadow; y: root.pxScale }
  Run { tone: root.tone }
}
