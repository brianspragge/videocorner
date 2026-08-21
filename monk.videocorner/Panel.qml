import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// VideoCorner root panel. Owns lifecycle, the KeyboardPanel and its content
// size, the keyCatcher and searchField (global input), shared state, settings
// persistence, and the wiring of SearchService/PlayerService and the views.
// Sub-views report their implicitHeight; services report results.
Panel {
  id: root
  moduleName: "monk.videocorner"
  ipcTarget: "monk.videocorner"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string mode: "home"
  property string searchText: ""
  property var results: []
  property var displayResults: Model.gridCells(root.results)
  readonly property bool searching: searchService.searching
  property int selectedIndex: -1
  property bool cursorActive: false
  property string pluginDir: {
    var url = Qt.resolvedUrl(".")
    return url.toString().replace("file://", "")
  }

  readonly property string corner: String(setting("corner", "top-right"))
  readonly property real size: {
    var s = Number(setting("size", 1))
    return (isFinite(s) && s > 0) ? s : 1
  }

  readonly property bool playing: player.playing
  readonly property string currentTitle: player.currentTitle
  property var monitors: player.monitors

  Component.onCompleted: player.restore()
  onOpenedChanged: {
    if (opened && monitors.length === 0) player.fetchMonitors()
  }

  // ---- lifecycle --------------------------------------------------------------
  function open() {
    root.controller.show()
    // Reliably focus the search field: scheduled after controller.show()
    // so it runs after KeyboardPanel's own focusTarget callLater and wins.
    Qt.callLater(function() {
      if (root.opened) searchField.forceActiveFocus()
    })
    focusRetry.restart()
  }

  // Some opens lose the focus race to KeyboardPanel's focusTarget priming;
  // keep re-asserting until the search field actually holds focus.
  Timer {
    id: focusRetry
    interval: 40
    repeat: true
    onTriggered: {
      if (!root.opened) { stop(); return }
      if (searchField.activeFocus) { stop(); return }
      searchField.forceActiveFocus()
    }
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function monitorName() {
    try { return root.anchorItem.QsWindow.window.monitor.name }
    catch (e) { return "" }
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setCorner(c) {
    persistSettings({ corner: c })
    Qt.callLater(player.reposition)
  }

  function setSize(s) {
    persistSettings({ size: s })
    Qt.callLater(player.reposition)
  }

  // ---- search ------------------------------------------------------------------
  function onSearchEdited(text) {
    searchText = text
    if (text.trim().length === 0) {
      results = []; mode = "home"
      searchService.clear()
      return
    }
    searchService.schedule()
  }

  function searchNow() {
    if (root.searchText.trim().length > 0) searchService.run()
  }

  // ---- playback ----------------------------------------------------------------
  function play(vid, title) {
    mode = "home"
    player.play(vid, title)
  }

  function stopClicked() {
    player.stop()
  }

  function moveCursor(delta) {
    var max = results.length - 1
    if (max < 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? max : 0
      return
    }
    selectedIndex = Math.max(0, Math.min(max, selectedIndex + delta))
  }

  // ---- services ----------------------------------------------------------------
  SearchService {
    id: searchService
    query: root.searchText.trim()
    onSearchStarted: function() { root.results = []; root.mode = "results" }
    onResultsReady: function(list) { root.results = list }
  }
  PlayerService {
    id: player
    corner: root.corner
    size: root.size
    monitorName: root.monitorName()
    pluginDir: root.pluginDir
  }

  // ---- key handling ------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(mode === "results" ? 580 : 320))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight)

    // Custom catcher rather than PanelKeyCatcher: needs Ctrl-modified keys
    // for window movement (Ctrl+arrows / Ctrl+hjkl) and resizing
    // (Ctrl+= / Ctrl++ / Ctrl+- / Ctrl+_), which the shared catcher can't do.
    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        var ctrl = event.modifiers & Qt.ControlModifier

        // ---- window resize (Shift+`=` reports Key_Plus, Shift+`-` reports Key_Underscore) ----
        if (ctrl && (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus)) {
          if (event.modifiers & Qt.ShiftModifier) root.setSize(2.5)
          else root.setSize(Model.stepSize(root.size, 1))
          event.accepted = true; return
        }
        if (ctrl && (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore)) {
          if (event.modifiers & Qt.ShiftModifier) root.setSize(0.5)
          else root.setSize(Model.stepSize(root.size, -1))
          event.accepted = true; return
        }

        // ---- Ctrl+Q: close the video window ----
        if (ctrl && event.key === Qt.Key_Q) {
          root.stopClicked()
          event.accepted = true; return
        }

        // ---- Esc / Ctrl+[: back to main view, close only when on main view ----
        if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_BracketLeft)) {
          if (root.mode === "results") {
            root.mode = "home"
          } else {
            root.close()
          }
          event.accepted = true; return
        }

        // ---- window movement (arrows + vim hjkl) ----
        if (ctrl) {
          var dx = 0, dy = 0
          if (event.key === Qt.Key_Up || event.key === Qt.Key_K) dy = -1
          else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) dy = 1
          else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) dx = -1
          else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) dx = 1
          if (dx !== 0 || dy !== 0) {
            root.setCorner(Model.nextCorner(root.corner, dx, dy))
            event.accepted = true; return
          }
          return
        }
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          root.switchPanel((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Down || event.text === "j") {
          root.moveCursor(1); event.accepted = true; return
        }
        if (event.key === Qt.Key_Up || event.text === "k") {
          root.moveCursor(-1); event.accepted = true; return
        }
        if (event.key === Qt.Key_Right || event.text === "l") {
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Left || event.text === "h") {
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (root.mode === "results") {
            if (root.cursorActive && root.selectedIndex >= 0) {
              var r = root.results[root.selectedIndex]
              if (r) root.play(r.vid, r.title)
            }
          } else if (root.searchText.trim().length > 0) {
            root.searchNow()
          }
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Space) {
          if (root.mode === "results" && root.cursorActive && root.selectedIndex >= 0) {
            var s = root.results[root.selectedIndex]
            if (s) root.play(s.vid, s.title)
          }
          event.accepted = true; return
        }
        // printable keys pass through to the search field
      }

      Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        // Header
        Row {
          spacing: Style.space(8)
          Text { text: "▶"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "VideoCorner"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }

        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Search YouTube…"
          foreground: root.foreground
          accent: Color.accent
          onTextChanged: root.onSearchEdited(text)
          onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
          Component.onCompleted: if (visible) Qt.callLater(forceActiveFocus)

          // The TextField natively eats Ctrl-modified editing shortcuts
          // (Ctrl+arrows word-jump, Ctrl+K etc.) in its C++ keyPressEvent
          // BEFORE the key event propagates up to keyCatcher. Intercept them
          // here with Keys.BeforeItem (runs before the item's own key
          // handling) so they drive the video window instead of the cursor.
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (!(event.modifiers & Qt.ControlModifier)) return

            // ---- window resize (Shift+`=` reports Key_Plus, Shift+`-` reports Key_Underscore) ----
            if (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus) {
              if (event.modifiers & Qt.ShiftModifier) root.setSize(2.5)
              else root.setSize(Model.stepSize(root.size, 1))
              event.accepted = true; return
            }
            if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
              if (event.modifiers & Qt.ShiftModifier) root.setSize(0.5)
              else root.setSize(Model.stepSize(root.size, -1))
              event.accepted = true; return
            }

            // ---- Ctrl+Q: close the video window ----
            if (event.key === Qt.Key_Q) {
              root.stopClicked()
              event.accepted = true; return
            }

            // ---- Ctrl+1..9: select and play the video at that number ----
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
              var n = event.key - Qt.Key_1 + 1
              if (n >= 1 && n <= root.results.length) {
                root.play(root.results[n-1].vid, root.results[n-1].title)
                event.accepted = true; return
              }
            }

            // ---- window movement (arrows + vim hjkl) ----
            var dx = 0, dy = 0
            if (event.key === Qt.Key_Up || event.key === Qt.Key_K) dy = -1
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) dy = 1
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) dx = -1
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) dx = 1
            if (dx !== 0 || dy !== 0) {
              root.setCorner(Model.nextCorner(root.corner, dx, dy))
              event.accepted = true
            }
          }
        }

        // home mode
        HomeView {
          visible: root.mode === "home"
          width: parent.width
          corner: root.corner
          size: root.size
          playing: root.playing
          currentTitle: root.currentTitle
          foreground: root.foreground
          dim: root.dim
          fontFamily: root.fontFamily
          onSetCorner: function(c) { root.setCorner(c) }
          onSetSize: function(s) { root.setSize(s) }
          onStopClicked: root.stopClicked()
        }

        // results mode
        ResultsView {
          visible: root.mode === "results"
          width: parent.width
          displayResults: root.displayResults
          resultCount: root.results.length
          searching: root.searching
          selectedIndex: root.selectedIndex
          cursorActive: root.cursorActive
          foreground: root.foreground
          dim: root.dim
          fontFamily: root.fontFamily
          onPlay: function(vid, title) { root.play(vid, title) }
          onBack: root.mode = "home"
        }
      }
    }
  }
}
