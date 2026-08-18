import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.odessa2.bing-wallpaper"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var marketOptions: [
    { value: "auto", label: "Automatic (" + (service ? service.effectiveMarket : "locale") + ")" },
    { value: "global", label: "Global / Rest of World" },
    { value: "de-DE", label: "Germany (de-DE)" },
    { value: "en-US", label: "United States (en-US)" },
    { value: "en-GB", label: "United Kingdom (en-GB)" },
    { value: "en-CA", label: "Canada (en-CA)" },
    { value: "en-IN", label: "India (en-IN)" },
    { value: "fr-FR", label: "France (fr-FR)" },
    { value: "fr-CA", label: "Canada (fr-CA)" },
    { value: "es-ES", label: "Spain (es-ES)" },
    { value: "it-IT", label: "Italy (it-IT)" },
    { value: "pt-BR", label: "Brazil (pt-BR)" },
    { value: "ja-JP", label: "Japan (ja-JP)" },
    { value: "ko-KR", label: "Korea (ko-KR)" },
    { value: "zh-CN", label: "China (zh-CN)" }
  ]

  function open() {
    root.controller.show()
    if (service) service.loadStatus()
  }

  function close() { root.controller.hide() }
  function toggle() { root.opened ? close() : open() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function save(nextMarket, nextSetWallpaper) {
    if (service) service.configure(nextMarket, nextSetWallpaper)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: marketDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: "Bing Wallpaper for Omarchy"
          meta: service && service.busy
            ? "Updating"
            : (service && service.lastRunAt !== "" ? "Updated " + service.lastRunAt.slice(0, 16).replace("T", " ") : "Ready")
          detail: service ? service.effectiveMarket : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        BorderSurface {
          width: parent.width
          height: Math.round(width * 9 / 16)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          radius: Style.cornerRadius
          clip: true

          Image {
            id: previewImage
            anchors.fill: parent
            source: service && service.currentImage && service.currentImage.localPath
              ? Util.fileUrl(String(service.currentImage.localPath))
              : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
          }

          Text {
            anchors.centerIn: parent
            visible: previewImage.status !== Image.Ready
            text: service && service.busy ? "Downloading image…" : "No image downloaded yet"
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Text {
          width: parent.width
          text: service && service.currentImage
            ? String(service.currentImage.copyright || service.currentImage.title || "Bing homepage image")
            : "Bing homepage image"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Dropdown {
          id: marketDropdown
          width: parent.width
          label: "Bing market"
          foreground: root.foreground
          fontFamily: root.fontFamily
          options: root.marketOptions
          value: service ? service.market : "auto"
          onChanged: function(value) {
            root.save(value, service ? service.setWallpaper : true)
          }
        }

        Toggle {
          width: parent.width
          label: "Set as wallpaper"
          description: "Turn off to keep downloading the selected market without changing the desktop."
          checked: service ? service.setWallpaper : true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (service) service.toggleSetWallpaper()
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: service && service.busy ? "Refreshing…" : "Refresh now"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            focusable: true
            enabled: service && !service.busy
            onClicked: if (service) service.refresh()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Right-click the bar widget to refresh"
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          width: parent.width
          visible: service && service.lastError !== ""
          text: service ? service.lastError : ""
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
