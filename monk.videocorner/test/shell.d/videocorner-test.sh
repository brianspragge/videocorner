#!/usr/bin/env bash
# Pure-logic tests for monk.videocorner Model.js, runnable under node.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODEL="$DIR/Model.js"

node - "$MODEL" <<'EOF'
var M = require(process.argv[2]);
var assert = require("assert");

// ---- geometry ----
assert.strictEqual(M.scaleOf({ scale: 2 }), 2);
assert.strictEqual(M.scaleOf({ scale: 0 }), 1);
assert.strictEqual(M.widthFor(2, 1), 720);
assert.strictEqual(M.heightFor(720), 405);
assert.strictEqual(M.heightFor(720, 1), 720);          // square
assert.strictEqual(M.heightFor(720, 0.5625), 1280);    // vertical 9:16
assert.strictEqual(M.aspectFrom(1920, 1080), 1920 / 1080);
assert.strictEqual(M.aspectFrom(1080, 1080), 1);
assert.strictEqual(M.aspectFrom(0, 0), 16 / 9);
assert.strictEqual(M.marginFor(1), 40);

var mon = { name: "eDP-1", scale: 1, x: 0, y: 0, width: 1920, height: 1200 };
assert.deepStrictEqual(M.localXY(mon, 360, 203, "top-left"), { x: 40, y: 40 });
assert.deepStrictEqual(M.localXY(mon, 360, 203, "top-right"), { x: 1520, y: 40 });
assert.deepStrictEqual(M.localXY(mon, 360, 203, "top"), { x: 780, y: 40 });
assert.deepStrictEqual(M.localXY(mon, 360, 203, "bottom"), { x: 780, y: 957 });
assert.deepStrictEqual(M.localXY(mon, 360, 203, "left"), { x: 40, y: 499 });
assert.deepStrictEqual(M.localXY(mon, 360, 203, "right"), { x: 1520, y: 499 });

// monitor selection falls back to focused, then first
assert.strictEqual(M.pickMonitor([mon], "eDP-1").name, "eDP-1");
assert.strictEqual(M.pickMonitor([mon], "missing").name, "eDP-1");
assert.strictEqual(M.pickMonitor([], "eDP-1"), undefined);

// ---- search parsing ----
assert.deepStrictEqual(M.parseResults("abc123\tMy Video\nxyz789\tAnother\n"), [
  { vid: "abc123", title: "My Video" },
  { vid: "xyz789", title: "Another" }
]);
assert.deepStrictEqual(M.parseResults(""), []);
assert.strictEqual(M.url("abc123"), "https://www.youtube.com/watch?v=abc123&videocorner=1");

// ---- results cap at 9 ----
var tenLines = ""
for (var li = 0; li < 10; li++) tenLines += "vid" + li + "\tTitle " + li + "\n"
assert.strictEqual(M.parseResults(tenLines).length, 9);

// ---- 3x3 grid in numpad order: bottom 1 2 3, middle 4 5 6, top 7 8 9 ----
var nine = []
for (var gi = 0; gi < 9; gi++) nine.push({ vid: "v" + gi, title: "t" + gi })
var cells = M.gridCells(nine)
assert.strictEqual(cells.length, 9);
assert.deepStrictEqual(cells.map(function (c) { return c.number }), [7, 8, 9, 4, 5, 6, 1, 2, 3]);
assert.deepStrictEqual(cells.map(function (c) { return c.vid }), ["v6", "v7", "v8", "v3", "v4", "v5", "v0", "v1", "v2"]);

// partial results: only existing numbers fill their numpad slots, rest null
var partial = M.gridCells(nine.slice(0, 4))
assert.deepStrictEqual(partial.map(function (c) { return c ? c.number : null }), [null, null, null, 4, null, null, 1, 2, 3]);

// empty search -> all null
assert.deepStrictEqual(M.gridCells([]).map(function (c) { return c }), [null, null, null, null, null, null, null, null, null]);

// ---- position grid (no wrap at edges, center skipped) ----
assert.strictEqual(M.nextCorner("top", 0, 1), "bottom");          // steps through center
assert.strictEqual(M.nextCorner("bottom", 0, -1), "top");
assert.strictEqual(M.nextCorner("left", 1, 0), "right");
assert.strictEqual(M.nextCorner("right", -1, 0), "left");
assert.strictEqual(M.nextCorner("top-left", 0, -1), "top-left");  // no wrap up
assert.strictEqual(M.nextCorner("top-left", -1, 0), "top-left");  // no wrap left
assert.strictEqual(M.nextCorner("bottom-right", 0, 1), "bottom-right");
assert.strictEqual(M.nextCorner("bottom-right", 1, 0), "bottom-right");
assert.strictEqual(M.nextCorner("top", 1, 0), "top-right");
assert.strictEqual(M.nextCorner("top", -1, 0), "top-left");
assert.strictEqual(M.nextCorner("left", 0, -1), "top-left");
assert.strictEqual(M.nextCorner("left", 0, 1), "bottom-left");
assert.strictEqual(M.nextCorner("right", 0, -1), "top-right");
assert.strictEqual(M.nextCorner("right", 0, 1), "bottom-right");
assert.strictEqual(M.nextCorner("nonsense", 1, 0), "nonsense");   // unknown corner passes through

// ---- size stepping (clamped at ends) ----
assert.strictEqual(M.stepSize(0.5, 1), 1);
assert.strictEqual(M.stepSize(1, 1), 1.5);
assert.strictEqual(M.stepSize(2.5, 1), 2.5);      // clamped at max
assert.strictEqual(M.stepSize(2.5, -1), 2);
assert.strictEqual(M.stepSize(0.5, -1), 0.5);     // clamped at min
assert.strictEqual(M.stepSize(1.7, 1), 2);        // unknown snaps to nearest, then steps
assert.strictEqual(M.stepSize(1.7, -1), 1);

console.log("all monk.videocorner model tests passed");
EOF