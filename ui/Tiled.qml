import QtQuick

// A layer that repeats every `period` px and is scrolled by `scroll`, always covering the 320 px view.
Item {
  id: root
  property url source
  property real period: 320
  property real scroll: 0
  property real yOffset: 0
  width: 320; height: 180
  readonly property real off: -Math.round(((scroll % period) + period) % period)
  Repeater {
    model: Math.ceil(320 / Math.max(1, root.period)) + 1
    Image {
      source: root.source
      smooth: false; cache: true; asynchronous: false
      x: root.off + index * root.period
      y: Math.round(root.yOffset)
    }
  }
}
