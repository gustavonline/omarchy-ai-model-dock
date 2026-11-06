import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: controls
  required property var controller
  spacing: Style.space(10)
  function tileLabel(model) {
    var match = String(model.id).match(/(\d+(?:\.\d+)?)b/i)
    return match ? match[1] + "B" : String(model.id).slice(0, 6)
  }
  function tileFamily(model) {
    return String(model.id).split(/[-_]/)[0].toUpperCase()
  }
  function modelSelection() {
    var models = controller.dock.models || []
    return models.find(function(model) { return model.id === controller.selectedDockModel }) || models[0] || null
  }
  PanelHero {
    width: parent.width
    title: controller.dock.configured ? (controller.dockRunning ? "Your models are on deck" : "Ready when you are") : "Make room for your models"
    meta: controller.dock.configured ? "PRIVATE API · " + controller.dock.max_loaded + " MODELS CAN STAY LOADED" : "LOCAL INFERENCE · YOUR HARDWARE"
    detail: controller.busy ? "Working…" : (controller.dock.ready ? "READY" : "LOCAL")
    foreground: controller.foreground
    fontFamily: controller.fontFamily
    iconComponent: Component {
      Text {
        text: "󰍛"
        color: controller.foreground
        font.family: controller.fontFamily
        font.pixelSize: Style.font.display
      }
    }
  }

  Text {
    width: parent.width
    text: "MODEL SLOTS · PRESS 1–5 TO LOAD"
    color: controller.dim
    font.family: controller.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 0.8
  }

  Flickable {
    id: hotbar
    width: parent.width
    height: Style.space(78)
    contentWidth: slotRow.width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    Row {
      id: slotRow
      spacing: Style.space(7)
      Repeater {
        model: Math.max(5, (controller.dock.models || []).length + 1)
        delegate: Item {
          id: slot
          required property int index
          readonly property var model: (controller.dock.models || [])[index] || null
          readonly property bool chosen: model !== null && controller.selectedDockModel === model.id
          readonly property bool loading: model !== null && (model.state === "loading"
            || (controller.busy && chosen && (controller.pendingAction === "load" || controller.pendingAction === "start")))
          width: (hotbar.width - Style.space(7) * 4) / 5
          height: hotbar.height
          Button {
            anchors.fill: parent
            text: slot.model ? controls.tileLabel(slot.model) : "+"
            selected: slot.chosen
            enabled: !controller.busy
            bordered: true
            foreground: controller.foreground
            fontFamily: controller.fontFamily
            fontSize: Style.font.title
            onClicked: {
              if (slot.model) controller.selectDockModel(slot.index)
              else controller.openDockSetup()
            }
          }
          Text {
            x: Style.space(6)
            y: Style.space(3)
            text: slot.index < 9 ? String(slot.index + 1) : ""
            color: controller.dim
            font.family: controller.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(8)
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Style.space(6)
            text: slot.model ? controls.tileFamily(slot.model) : "ADD"
            color: controller.dim
            font.family: controller.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
          Rectangle {
            visible: slot.model !== null && (slot.model.state === "loaded" || slot.loading)
            x: Style.space(6)
            width: parent.width - Style.space(12)
            height: Style.space(2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(3)
            color: controller.foreground
            SequentialAnimation on opacity {
              running: slot.loading
              loops: Animation.Infinite
              NumberAnimation { from: 0.2; to: 1; duration: 420 }
              NumberAnimation { from: 1; to: 0.2; duration: 420 }
            }
            onVisibleChanged: if (!slot.loading) opacity = 1
          }
        }
      }
    }
  }

  Column {
    visible: selectedModel !== null
    width: parent.width
    spacing: Style.space(3)
    readonly property var selectedModel: controls.modelSelection()
    Text {
      text: parent.selectedModel ? parent.selectedModel.id : ""
      width: parent.width
      color: controller.foreground
      font.family: controller.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: parent.selectedModel ? (parent.selectedModel.context / 1024) + "K context · "
        + parent.selectedModel.slots + (parent.selectedModel.slots === 1 ? " request at a time · " : " simultaneous requests · ")
        + (parent.selectedModel.state === "loaded" ? "Ready" : "Loads on request") : ""
      color: controller.dim
      font.family: controller.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  Row {
    visible: controller.dock.configured === true
    width: parent.width
    spacing: Style.spacing.md
    Button {
      width: (parent.width - parent.spacing) / 2
      text: controller.busy ? "Working…" : (controller.dockRunning ? "Stop server" : "Start server")
      iconText: controller.busy ? "󰦖" : (controller.dockRunning ? "󰓛" : "󰐊")
      iconSpinning: controller.busy
      enabled: !controller.busy
      bordered: true
      foreground: controller.foreground
      fontFamily: controller.fontFamily
      onClicked: controller.runDockAction(controller.dockRunning ? "stop" : "start")
    }
    Button {
      width: (parent.width - parent.spacing) / 2
      text: "Copy API URL"
      enabled: controller.dock.ready === true
      bordered: true
      foreground: controller.foreground
      fontFamily: controller.fontFamily
      onClicked: controller.copyEndpoint()
    }
  }

  Toggle {
    visible: controller.dock.configured === true
    width: parent.width
    label: "Start at login"
    description: "Keep the server available after login"
    checked: controller.dock.autostart === true
    foreground: controller.foreground
    accent: controller.accent
    fontFamily: controller.fontFamily
    enabled: !controller.busy
    onClicked: controller.runDockAction("autostart", controller.dock.autostart ? "off" : "on")
  }

  Button {
    visible: controller.dockRunning && controller.dock.needs_restart === true
    width: parent.width
    text: "Apply changes · restart server"
    bordered: true
    foreground: controller.foreground
    fontFamily: controller.fontFamily
    enabled: !controller.busy
    onClicked: controller.runDockAction("restart")
  }

  Button {
    visible: controller.dock.configured === true
    width: parent.width
    text: "Copy selected model ID"
    enabled: controller.selectedDockModel !== ""
    foreground: controller.dim
    fontFamily: controller.fontFamily
    onClicked: controller.copyDockModel()
  }

  Button {
    width: parent.width
    text: controller.dock.configured ? "Add a model…" : "Set up Model Dock…"
    bordered: !controller.dock.configured
    foreground: controller.foreground
    fontFamily: controller.fontFamily
    onClicked: controller.openDockSetup()
  }

  Text {
    visible: !controller.dock.configured
    width: parent.width
    text: "A short terminal setup gets you started. Ask your agent to choose and tune a model for your work."
    color: controller.dim
    font.family: controller.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    visible: controller.feedback !== ""
    width: parent.width
    text: controller.feedback
    color: controller.feedbackIsError ? controller.urgent : controller.accent
    font.family: controller.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Button {
    visible: (controller.status.profiles || []).length > 0
    width: parent.width
    text: controller.showLegacy ? "Hide existing profiles" : "Existing runtime profiles…"
    foreground: controller.dim
    fontFamily: controller.fontFamily
    onClicked: controller.showLegacy = !controller.showLegacy
  }
}
