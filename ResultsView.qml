import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The results-mode view: a Back row plus the 3x3 video grid (numpad-ordered
// 789 / 456 / 123) with number badges, hover and keyboard-selection highlight.
// It is purely visual — it renders from the supplied displayResults and reports
// its implicitHeight; the root owns results/mode and plays on request.
Item {
  id: root

  required property var displayResults
  required property int resultCount
  required property bool searching
  required property int selectedIndex
  required property bool cursorActive
  required property color foreground
  required property color dim
  required property string fontFamily

  signal play(string vid, string title)
  signal back()

  width: parent ? parent.width : 0
  implicitHeight: col.implicitHeight

  Column {
    id: col
    width: parent.width
    spacing: Style.space(8)

    Row {
      width: parent.width
      spacing: Style.space(8)
      Button { text: "Back"; foreground: root.foreground; anchors.verticalCenter: parent.verticalCenter; onClicked: root.back() }
      Text {
        text: root.searching ? "Searching…" : (root.resultCount === 0 ? "No videos found" : "")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      width: parent.width
      implicitHeight: resultsGrid.implicitHeight
      Grid {
        id: resultsGrid
        columns: 3
        spacing: Style.space(8)
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: root.displayResults

          Item {
            id: card
            required property var modelData
            required property int index
            width: Style.space(150)
            height: cardCol.implicitHeight
            implicitHeight: cardCol.implicitHeight
            visible: modelData !== null

            Column {
              id: cardCol
              width: parent.width
              spacing: Style.space(4)

              Item {
                id: thumbBox
                width: parent.width
                height: Math.round(width * 9 / 16)
                Rectangle { anchors.fill: parent; radius: Style.cornerRadius; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) }
                Image {
                  anchors.fill: parent
                  source: card.modelData ? Model.thumb(card.modelData.vid) : ""
                  asynchronous: true
                  fillMode: Image.PreserveAspectCrop
                  visible: status === Image.Ready
                }
                Text {
                  anchors.centerIn: parent
                  visible: parent.children[1].status !== Image.Ready
                  text: "󰐊"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                }

                // Number badge, centered on the thumbnail. Theme-driven
                // colors keep it legible on any thumbnail image.
                Rectangle {
                  id: badge
                  anchors.centerIn: parent
                  width: Style.space(26)
                  height: Style.space(26)
                  radius: width / 2
                  color: Util.alpha(Color.background, 0.65)
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.55)
                  Text {
                    anchors.centerIn: parent
                    text: card.modelData ? card.modelData.number : ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: root.foreground
                  opacity: (root.cursorActive && card.modelData && root.selectedIndex === card.modelData.number - 1) || cardMouse.containsMouse ? 0.12 : 0
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }
              }

              Text {
                text: card.modelData ? card.modelData.title : ""
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            MouseArea {
              id: cardMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (card.modelData) root.play(card.modelData.vid, card.modelData.title)
            }
          }
        }
      }
    }
  }
}
