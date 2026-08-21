import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Runs the incremental YouTube search. Owns the yt-dlp Process and the
// debounce; parses the tab-delimited results and emits `resultsReady`. It does
// not open, close, or size the panel — the root sets `query` and calls
// schedule() (debounced, for typing). The root owns `results`/`mode` and
// consumes the emitted list.
Item {
  id: root

  property string query: ""
  property bool searching: false
  signal searchStarted()
  signal resultsReady(var list)

  // Debounced search (typing).
  function schedule() { debounce.restart() }

  // Stop any pending search and report empty results.
  function clear() {
    debounce.stop()
    root.searching = false
    root.resultsReady([])
  }

  function run() {
    var q = root.query.trim()
    if (!q) {
      debounce.stop()
      root.searching = false
      root.resultsReady([])
      return
    }
    if (proc.running) { proc.rerun = true; return }
    proc.rerun = false
    proc.running = true
    root.searching = true
    root.searchStarted()
  }

  Timer {
    id: debounce
    interval: 500
    onTriggered: root.run()
  }

  Process {
    id: proc
    property bool rerun: false
    command: ["yt-dlp", "ytsearch9:" + root.query.trim(), "--flat-playlist", "--no-warnings", "--print", "%(id)s\t%(title)s"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.resultsReady(Model.parseResults(text))
        root.searching = false
      }
    }
    onExited: function(code) {
      root.searching = false
      if (code !== 0) root.resultsReady([])
      if (rerun) { rerun = false; root.run() }
    }
  }
}
