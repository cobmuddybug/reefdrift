.pragma library
.import "atlas.js" as Atlas

// Maps what the sim has (species, radius, frame, facing) to a rectangle of the baked sheet.
// Keys match the web game's memo keys exactly (see dev/tools/bake-sprites.mjs).
function fishLength(r, sp) {
  var k = sp === "moray" ? 1.45 : (sp === "reef_shark" || sp === "tiger_shark") ? 1.15 : 1
  return Math.max(5, Math.round(r * 3.1 * k))
}
// kind: "c" creature, "p" player, "coral" scenery (then `sp` is the coral kind, r the variant, facing the size)
function lookup(kind, sp, r, frame, facing) {
  var key
  if (kind === "p") key = "p:" + fishLength(r) + ":" + (frame % 2) + ":" + (facing < 0 ? -1 : 1)
  else if (kind === "c") {
    var sym = sp === "jellyfish"
    var fr = sp === "manta" ? frame % 4 : frame % 2
    key = "c:" + sp + ":" + fishLength(r, sp) + ":" + fr + ":" + (sym ? 0 : (facing < 0 ? -1 : 1))
  } else key = "coral:" + sp + ":" + (r % 4) + ":" + Math.max(6, Math.round(facing)) + ":" + (frame % 2)
  return Atlas.SPRITES[key] || null
}
