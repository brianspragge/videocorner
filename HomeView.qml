import QtQuick
import qs.Commons
import qs.Ui

// The home-mode view: player position selector (3x3 corner grid), size
// selector, and the currently-playing row with a Close button. It is purely
// visual — it reports its implicitHeight and emits corner/size/stop events;
// the root persists settings and repositions the player.
Item {
  id: root

  required property string corner
  required property real size
  required property bool playing
  required property string currentTitle
  required property color foreground
  required property color dim
  required property string fontFamily

  signal setCorner(string corner)
  signal setSize(real size)
  signal stopClicked()

  width: parent ? parent.width : 0
  implicitHeight: col.implicitHeight

  Column {
    id: col
    width: parent.width
    spacing: Style.space(10)

    Text { text: "Position"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Grid {
      columns: 3
      spacing: Style.space(6)
      Button { text: "↖"; foreground: root.foreground; selected: root.corner === "top-left";     onClicked: root.setCorner("top-left") }
      Button { text: "↑"; foreground: root.foreground; selected: root.corner === "top";           onClicked: root.setCorner("top") }
      Button { text: "↗"; foreground: root.foreground; selected: root.corner === "top-right";    onClicked: root.setCorner("top-right") }
      Button { text: "←"; foreground: root.foreground; selected: root.corner === "left";         onClicked: root.setCorner("left") }
      Text   { width: Style.space(38) }
      Button { text: "→"; foreground: root.foreground; selected: root.corner === "right";        onClicked: root.setCorner("right") }
      Button { text: "↙"; foreground: root.foreground; selected: root.corner === "bottom-left"; onClicked: root.setCorner("bottom-left") }
      Button { text: "↓"; foreground: root.foreground; selected: root.corner === "bottom";        onClicked: root.setCorner("bottom") }
      Button { text: "↘"; foreground: root.foreground; selected: root.corner === "bottom-right";onClicked: root.setCorner("bottom-right") }
    }

    Text { text: "Size"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Row {
      spacing: Style.space(6)
      Button { text: "0.5×"; foreground: root.foreground; selected: Math.abs(root.size - 0.5) < 0.01; onClicked: root.setSize(0.5) }
      Button { text: "1×";   foreground: root.foreground; selected: Math.abs(root.size - 1)   < 0.01; onClicked: root.setSize(1) }
      Button { text: "1.5×"; foreground: root.foreground; selected: Math.abs(root.size - 1.5) < 0.01; onClicked: root.setSize(1.5) }
      Button { text: "2×";   foreground: root.foreground; selected: Math.abs(root.size - 2)   < 0.01; onClicked: root.setSize(2) }
      Button { text: "2.5×"; foreground: root.foreground; selected: Math.abs(root.size - 2.5) < 0.01; onClicked: root.setSize(2.5) }
    }

    PanelSeparator { visible: root.playing; foreground: root.foreground }
    Row {
      visible: root.playing
      width: parent.width
      spacing: Style.space(8)
      Text {
        text: "󰐊 " + root.currentTitle
        textFormat: Text.PlainText
        width: parent.width - closeBtn.implicitWidth - Style.space(8)
        elide: Text.ElideRight
        color: Qt.darker(root.foreground, 1.3)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.verticalCenter: parent.verticalCenter
      }
      Button {
        id: closeBtn
        text: "Close"
        foreground: root.foreground
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.stopClicked()
      }
    }
  }
}
