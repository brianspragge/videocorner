// Pure geometry/position logic for the monk.videocorner player panel.
// Everything here is Qt-free so it can be unit tested under node
// (test/shell.d/videocorner-test.sh); the QML owns UI, key handling,
// and Process runs.

// ---- geometry ------------------------------------------------------------------

var BASE_WIDTH   = 360
var MARGIN       = 40
var ASPECT       = 9 / 16
var DEFAULT_ASPECT = 16 / 9

function scaleOf(mon)   { var s = mon && Number(mon.scale); return (s > 0) ? s : 1 }
function widthFor(s, k) { return Math.round(BASE_WIDTH * Math.max(s, 0.1) * Math.max(k, 1)) }
function aspectFrom(w, h) { return (Number(w) > 0 && Number(h) > 0) ? Number(w) / Number(h) : DEFAULT_ASPECT }
function heightFor(w, aspectWH) {
  var a = Number(aspectWH)
  if (!(a > 0)) a = DEFAULT_ASPECT
  return Math.round(w / a)
}
function marginFor(k)   { return Math.round(MARGIN * Math.max(k, 1)) }

// ---- monitor selection ------------------------------------------------------------

function pickMonitor(monitors, name) {
  if (!Array.isArray(monitors)) return null
  for (var i = 0; i < monitors.length; i++) if (monitors[i] && monitors[i].name === name) return monitors[i]
  for (var j = 0; j < monitors.length; j++) if (monitors[j] && monitors[j].focused) return monitors[j]
  return monitors[0]
}

// ---- position ----------------------------------------------------------------------

function localXY(mon, w, h, corner) {
  var m = marginFor(scaleOf(mon))
  var x = m, y = m
  if (corner === "top"       || corner === "bottom") x = Math.round((mon.width - w) / 2)
  if (corner === "left"      || corner === "right")  y = Math.round((mon.height - h) / 2)
  if (corner === "top-right" || corner === "bottom-right" || corner === "right") x = mon.width - w - m
  if (corner === "bottom-left" || corner === "bottom-right" || corner === "bottom") y = mon.height - h - m
  return { x: x, y: y }
}

function globalXY(mon, w, h, corner) {
  var l = localXY(mon, w, h, corner)
  return { x: mon.x + l.x, y: mon.y + l.y }
}

// ---- results ------------------------------------------------------------------------

function parseResults(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var t = lines[i].indexOf("\t")
    if (t > 0) out.push({ vid: lines[i].slice(0, t).trim(), title: lines[i].slice(t + 1).trim() })
    if (out.length >= 9) break
  }
  return out
}

// 3x3 results grid laid out in numpad order: bottom row 1 2 3, middle 4 5 6,
// top row 7 8 9. `visualIndex` maps grid position (top row first) to the
// search-result index; each cell is `{ vid, title, number }` where number is
// the 1-based search order, or null when fewer than 9 results are available.
function gridCells(results) {
  var visualIndex = [6, 7, 8, 3, 4, 5, 0, 1, 2]
  var cells = []
  for (var i = 0; i < visualIndex.length; i++) {
    var src = visualIndex[i]
    cells.push(src < results.length
      ? { vid: results[src].vid, title: results[src].title, number: src + 1 }
      : null)
  }
  return cells
}

function thumb(vid) { return "https://i.ytimg.com/vi/" + vid + "/mqdefault.jpg" }
function url(vid)   { return "https://www.youtube.com/watch?v=" + vid + "&videocorner=1" }

// ---- position/size navigation ------------------------------------------------

// The 3x3 position grid; the center cell is intentionally empty (no
// "center" corner), so movement steps through it.
var GRID = [
  ["top-left", "top", "top-right"],
  ["left", null, "right"],
  ["bottom-left", "bottom", "bottom-right"]
]

// Default size steps, matching the panel's size buttons.
var SIZES = [0.5, 1, 1.5, 2, 2.5]

// Move from `corner` one step in the (dx, dy) direction over GRID.
// No wrapping at the edges: a move that would leave the grid keeps the
// current corner. Stepping into the empty center continues one more step
// in the same direction (e.g. top+down -> bottom, left+right -> right).
function nextCorner(corner, dx, dy) {
  var row = -1, col = -1
  for (var r = 0; r < 3; r++)
    for (var c = 0; c < 3; c++)
      if (GRID[r][c] === corner) { row = r; col = c }
  if (row < 0) return corner
  var steps = 0
  while (steps < 2) {
    steps++
    var nr = row + dy, nc = col + dx
    if (nr < 0 || nr > 2 || nc < 0 || nc > 2) return corner
    if (GRID[nr][nc] !== null) return GRID[nr][nc]
    row = nr; col = nc
  }
  return corner
}

// Move one size step up/down in SIZES, clamped at the ends (no wrap).
function stepSize(current, delta) {
  var i = SIZES.indexOf(current)
  if (i < 0) {
    var best = 0, bestDiff = Infinity
    for (var j = 0; j < SIZES.length; j++) {
      var d = Math.abs(SIZES[j] - current)
      if (d < bestDiff) { bestDiff = d; best = j }
    }
    i = best
  }
  var target = i + delta
  if (target < 0) target = 0
  if (target > SIZES.length - 1) target = SIZES.length - 1
  return SIZES[target]
}

if (typeof module !== "undefined") {
  module.exports = {
    BASE_WIDTH: BASE_WIDTH,
    MARGIN: MARGIN,
    ASPECT: ASPECT,
    scaleOf: scaleOf,
    widthFor: widthFor,
    aspectFrom: aspectFrom,
    heightFor: heightFor,
    marginFor: marginFor,
    pickMonitor: pickMonitor,
    localXY: localXY,
    globalXY: globalXY,
    parseResults: parseResults,
    gridCells: gridCells,
    thumb: thumb,
    url: url,
    nextCorner: nextCorner,
    stepSize: stepSize,
    SIZES: SIZES
  }
}
