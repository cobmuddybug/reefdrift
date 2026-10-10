#!/bin/bash
# Boots every screen in the headless harness, swims for a while, checks state and QML errors.
cd "$(dirname "$0")/../.."
export REEFDRIFT_HOME="$(mktemp -d)"
printf 'not json' > "$REEFDRIFT_HOME/save.json"      # a corrupt save must not break the game
script="w10,status,k:Down,w2,k:Up,w2,k:Return,w10,d:Right,w60,d:Up,w40,u:Right,u:Up,k:Space,w20,k:Escape,w3,status,k:Down,w2,k:Up,w2,k:Escape,w10,blur,status,go:title,w3,scene:26:0.75,w30,status,ff:60,status,quit"
out=$(TIMEOUT=240 dev/tools/run.sh "$script")
echo "$out" | grep -v REEFDRIFT_STATUS
echo "$out" | grep -q REEFDRIFT_STATUS || { echo "harness did not finish"; exit 1; }
if echo "$out" | grep -v REEFDRIFT_ | grep -q .; then echo "SMOKE FAILED"; exit 1; fi
echo "$out" | grep REEFDRIFT_STATUS | sed 's/.*REEFDRIFT_STATUS //' > "$REEFDRIFT_HOME/status.jsonl"
node -e '
const L = require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse)
const bad = (m) => { console.error("bad status: " + m); process.exit(1) }
if (L.length !== 5) bad("expected 5 status lines, got " + L.length)
if (L[0].screen !== "title") bad("starts on title: " + JSON.stringify(L[0]))
if (L[1].screen !== "pause") bad("Escape pauses: " + JSON.stringify(L[1]))
if (L[2].held !== 0) bad("blur clears held keys: " + JSON.stringify(L[2]))
for (const s of L) if (!(s.r >= 3 && s.r <= 26 && s.time >= 0 && s.time < 1)) bad("range: " + JSON.stringify(s))
if (L[4].creatures < 1) bad("creatures after ff")
' "$REEFDRIFT_HOME/status.jsonl" || { echo "SMOKE FAILED"; exit 1; }
# the sea must scroll with the camera while swimming (QML bindings do not see in-place changes to an object)
out2=$(TIMEOUT=60 dev/tools/run.sh "scene:10:0.25,w5,d:Right,w60,status,quit" | grep REEFDRIFT_STATUS | sed 's/.*REEFDRIFT_STATUS //')
echo "$out2" | node -e '
const s = JSON.parse(require("fs").readFileSync(0, "utf8"))
if (Math.abs(s.seaScroll + 160 - s.camX) > 1) { console.error("sea layer is not following the camera: " + JSON.stringify({ camX: s.camX, seaScroll: s.seaScroll })); process.exit(1) }
' || { echo "SMOKE FAILED"; exit 1; }
# a fading night step must be flattened, or the incoming water paints over the outgoing seabed (muddy sand at dusk)
out4=$(TIMEOUT=60 dev/tools/run.sh "scene:10:0.5,w10,status,quit" | grep REEFDRIFT_STATUS | sed 's/.*REEFDRIFT_STATUS //')
echo "$out4" | node -e '
const s = JSON.parse(require("fs").readFileSync(0, "utf8"))
if (!(s.mixB > 0 && s.blendFlat === true)) { console.error("dusk blend is not flattened: " + JSON.stringify(s)); process.exit(1) }
' || { echo "SMOKE FAILED"; exit 1; }
# Esc on the title screen asks the overlay to close (there must be a keyboard way out)
out3=$(TIMEOUT=60 dev/tools/run.sh "w10,k:Escape,w3,status,quit" | grep REEFDRIFT_STATUS | sed 's/.*REEFDRIFT_STATUS //')
echo "$out3" | node -e '
const s = JSON.parse(require("fs").readFileSync(0, "utf8"))
if (s.closeRequests !== 1) { console.error("Esc on the title did not request close: " + JSON.stringify(s)); process.exit(1) }
' || { echo "SMOKE FAILED"; exit 1; }
# Alt+W closes the overlay from anywhere (title, swim, pause) and must not also swim up
out5=$(TIMEOUT=60 dev/tools/run.sh "w10,k:alt+W,w3,status,k:Return,w10,k:alt+W,w3,status,k:Escape,w3,k:alt+W,w3,status,quit" | grep REEFDRIFT_STATUS | sed 's/.*REEFDRIFT_STATUS //')
echo "$out5" | node -e '
const L = require("fs").readFileSync(0, "utf8").trim().split("\n").map(JSON.parse)
if (L.length !== 3) { console.error("expected 3 status lines"); process.exit(1) }
L.forEach((s, i) => { if (s.closeRequests !== i + 1) { console.error("Alt+W did not request close (" + ["title", "swim", "pause"][i] + "): " + JSON.stringify(s)); process.exit(1) } })
if (L[1].screen !== "swim" || L[2].screen !== "pause") { console.error("Alt+W changed the screen: " + JSON.stringify(L)); process.exit(1) }
' || { echo "SMOKE FAILED"; exit 1; }
echo "smoke ok"
