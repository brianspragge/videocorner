import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Owns the floating video player lifecycle: restoring a playing session on
// startup, fetching the monitor list, launching/positioning the player window,
// and polling its liveness. It does not open, close, or size the panel — the
// root binds corner/size/monitorName/pluginDir and calls play()/stop()/restore().
// Playback state (playing, currentTitle, monitors) is read by the root.
Item {
  id: root

  property string corner: "top-right"
  property real size: 1
  property real aspect: 16 / 9
  property string monitorName: ""
  property string pluginDir: ""

  property bool playing: false
  property string currentTitle: ""
  property string pendingVid: ""
  property var monitors: []
  property bool playAfterMonitors: false
  property string aspectVid: ""

  // Restore a session that was left playing (player-ipc title returns 0).
  function restore() {
    if (!restoreProc.running) restoreProc.running = true
  }

  function fetchMonitors() {
    if (!monitorsProc.running) monitorsProc.running = true
  }

  function play(vid, title) {
    root.currentTitle = title; root.pendingVid = vid
    // Non-blocking aspect detection for the selected video.
    root.aspectVid = vid
    if (aspectProc.running) aspectProc.running = false
    aspectProc.running = true
    if (root.monitors.length === 0) {
      root.playAfterMonitors = true
      root.fetchMonitors()
      return
    }
    root.launchPlayer()
  }

  function launchPlayer() {
    var mon = Model.pickMonitor(root.monitors, root.monitorName)
    if (!mon) { root.playing = false; return }
    var k = Model.scaleOf(mon)
    var w = Model.widthFor(root.size, k)
    var h = Model.heightFor(w, root.aspect)
    var position = Model.globalXY(mon, w, h, root.corner)
    Quickshell.execDetached([root.pluginDir + "/launch.sh", Model.url(root.pendingVid), String(position.x), String(position.y), String(w), String(h)])
    root.playing = true
    pollTimer.restart()
  }

  function reposition() {
    if (!root.playing) return
    var mon = Model.pickMonitor(root.monitors, root.monitorName)
    if (!mon) return
    var k = Model.scaleOf(mon)
    var w = Model.widthFor(root.size, k)
    var h = Model.heightFor(w, root.aspect)
    var position = Model.globalXY(mon, w, h, root.corner)
    Quickshell.execDetached([root.pluginDir + "/reposition.sh", String(position.x), String(position.y), String(w), String(h)])
  }

  function stop() {
    root.playing = false
    pollTimer.stop()
    Quickshell.execDetached([root.pluginDir + "/close-player.sh"])
  }

  Process {
    id: restoreProc
    command: [root.pluginDir + "/player-ipc.py", "title"]
    stdout: StdioCollector {
      waitForEnd: true
      property string captured: ""
      onStreamFinished: { captured = text.trim() }
    }
    onExited: function(code) {
      if (code === 0) {
        root.playing = true
        root.currentTitle = stdout.captured
        pollTimer.restart()
      }
    }
  }

  // Fetch the selected video's native dimensions to derive its aspect ratio.
  // Runs in the background; the player launches immediately and snaps to the
  // real aspect when this completes.
  Process {
    id: aspectProc
    command: ["yt-dlp", "https://www.youtube.com/watch?v=" + root.aspectVid, "--no-warnings", "--print", "%(width)s\t%(height)s"]
    stdout: StdioCollector {
      waitForEnd: true
      property int outW: 0
      property int outH: 0
      onStreamFinished: {
        var m = String(text).match(/^\s*(\d+)\s+(\d+)/)
        if (m) { outW = Number(m[1]); outH = Number(m[2]) }
        else { outW = 0; outH = 0 }
      }
    }
    onExited: function(code) {
      // Only apply if this is still the current video (guard against quick switching).
      if (code !== 0 || root.aspectVid !== root.pendingVid) return
      var a = Model.aspectFrom(stdout.outW, stdout.outH)
      if (Math.abs(a - root.aspect) > 0.001) {
        root.aspect = a
        root.reposition()
      }
    }
  }

  Process {
    id: monitorsProc
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.monitors = JSON.parse(text) } catch (e) { root.monitors = [] }
      }
    }
    onExited: {
      if (root.playAfterMonitors) {
        root.playAfterMonitors = false
        root.launchPlayer()
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 3000
    repeat: true
    onTriggered: if (!pollProc.running) pollProc.running = true
  }

  Process {
    id: pollProc
    command: [root.pluginDir + "/player-alive.sh"]
    onExited: function(code) {
      if (code !== 0) { root.playing = false; pollTimer.stop() }
    }
  }
}
