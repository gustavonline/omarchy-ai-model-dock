import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.gustavonline.local-ai"
  ipcTarget: "io.github.gustavonline.local-ai"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string dockPath: decodeURIComponent(String(Qt.resolvedUrl("model-dock")).replace(/^file:\/\//, ""))
  readonly property string controlPath: decodeURIComponent(String(Qt.resolvedUrl("local-ai-control")).replace(/^file:\/\//, ""))
  readonly property string configFile: String(setting("localConfigFile", "~/.config/omarchy/local-ai.toml"))
  readonly property int refreshInterval: Math.max(5, Number(setting("refreshIntervalSec", 10))) * 1000

  property var dock: ({configured: false, active: false, ready: false, models: [], state: "stopped"})
  property var status: ({state: "inactive", endpoint: "", profiles: []})
  property string selectedDockModel: ""
  property bool showLegacy: false
  property bool busy: false
  property string pendingAction: ""
  property bool loadAfterDockStart: false
  property string feedback: ""
  property bool feedbackIsError: false
  property string copyLabel: "API URL copied"
  readonly property bool dockRunning: dock.active === true
  readonly property string dockEndpoint: String(dock.endpoint || "")
  readonly property bool legacyRunning: status.state === "active"

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!dockStatusProcess.running) dockStatusProcess.running = true
    if (!legacyStatusProcess.running) legacyStatusProcess.running = true
  }

  function showFeedback(message, error) {
    feedback = message
    feedbackIsError = error === true
    feedbackTimer.restart()
  }

  function runDockAction(action, argument) {
    if (actionProcess.running) return
    busy = true
    pendingAction = action
    feedback = ""
    actionProcess.command = [dockPath, action]
    if (argument) actionProcess.command.push(argument)
    actionProcess.running = true
  }

  function runLegacyAction(action, profile) {
    if (actionProcess.running) return
    busy = true
    pendingAction = action
    feedback = ""
    actionProcess.command = [controlPath, "--config", configFile, action]
    if (profile) actionProcess.command.push(profile)
    actionProcess.running = true
  }

  function selectDockModel(index) {
    var model = (dock.models || [])[index]
    if (!model || busy) return
    selectedDockModel = model.id
    if (dock.ready) runDockAction("load", model.id)
    else {
      loadAfterDockStart = true
      runDockAction("start")
    }
  }

  function moveDockSelection(delta) {
    var models = dock.models || []
    if (!models.length) return
    var index = models.findIndex(function(model) { return model.id === selectedDockModel })
    selectedDockModel = models[(index + delta + models.length) % models.length].id
  }

  function copyText(value, label) {
    if (!value || copyProcess.running) return
    copyLabel = label
    copyProcess.command = ["wl-copy", value]
    copyProcess.running = true
  }

  function copyEndpoint(legacy) {
    copyText(legacy ? String(status.endpoint || "") : dockEndpoint, "API URL copied")
  }

  function copyDockModel() { copyText(selectedDockModel, "Model ID copied") }

  function openDockSetup() {
    if (setupProcess.running) return
    setupProcess.command = ["omarchy", "launch", "terminal", "--", "bash", "-c",
      '"$1" setup; printf "\\nPress Enter to close"; read -r', "model-dock", dockPath]
    setupProcess.running = true
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Timer { interval: root.refreshInterval; running: true; repeat: true; onTriggered: root.refresh() }
  Timer { id: feedbackTimer; interval: 6000; onTriggered: root.feedback = "" }

  Process {
    id: dockStatusProcess
    command: [root.dockPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.dock = JSON.parse(String(text || "{}"))
          var models = root.dock.models || []
          if (!models.some(function(model) { return model.id === root.selectedDockModel })) {
            var loaded = models.find(function(model) { return model.state === "loaded" })
            root.selectedDockModel = loaded ? loaded.id : (models.length ? models[0].id : "")
          }
        } catch (e) { root.showFeedback("Could not read Model Dock status", true) }
      }
    }
    stderr: StdioCollector { id: dockError; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) root.showFeedback(String(dockError.text || "Model Dock needs attention").trim().slice(0, 180), true)
    }
  }

  Process {
    id: legacyStatusProcess
    command: [root.controlPath, "--config", root.configFile, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.status = JSON.parse(String(text || "{}")) }
        catch (e) { root.showFeedback("Could not read existing runtime profiles", true) }
      }
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(code) {
      var followUp = code === 0 && root.pendingAction === "start" && root.loadAfterDockStart
      var labels = {load: "Model ready", start: "Server started", stop: "Server stopped", restart: "Server restarted", autostart: "Startup preference saved"}
      root.busy = false
      if (code === 0) root.showFeedback(labels[root.pendingAction] || "Runtime updated", false)
      else root.showFeedback(String(actionError.text || actionOutput.text || "Runtime action failed").trim().slice(0, 220), true)
      root.pendingAction = ""
      root.loadAfterDockStart = false
      root.refresh()
      if (followUp) Qt.callLater(function() { root.runDockAction("load", root.selectedDockModel) })
    }
  }

  Process {
    id: copyProcess
    onExited: function(code) { root.showFeedback(code === 0 ? root.copyLabel : "Could not copy", code !== 0) }
  }
  Process { id: setupProcess; onExited: root.refresh() }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function start(profile: string): string {
      if (profile) root.runLegacyAction("start", profile)
      else root.runDockAction("start")
      return "ok"
    }
    function stop(): string { root.runDockAction("stop"); return "ok" }
    function restart(): string { root.runDockAction("restart"); return "ok" }
    function status(): string { return String(root.dock.state || "stopped") }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    tooltipText: "Model Dock · " + String(root.dock.state || "stopped")
    active: root.dockRunning || root.legacyRunning
    useActiveColor: false
    Rectangle {
      visible: root.dockRunning || root.legacyRunning
      width: Style.space(4)
      height: width
      radius: width / 2
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(2)
      color: root.foreground
    }
    onPressed: function(code) {
      if (code === Qt.RightButton && root.dock.configured) root.runDockAction(root.dockRunning ? "stop" : "start")
      else if (code === Qt.MiddleButton && root.dockRunning) root.runDockAction("restart")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(680))
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (/^[1-9]$/.test(text)) root.selectDockModel(Number(text) - 1)
      }
      onMoveRequested: function(dx, dy) { root.moveDockSelection(dx || dy) }
      onActivateRequested: {
        var models = root.dock.models || []
        root.selectDockModel(models.findIndex(function(model) { return model.id === root.selectedDockModel }))
      }
      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
        Column {
          id: content
          width: scroll.width
          spacing: Style.space(12)
          Row {
            width: parent.width
            Text {
              width: parent.width - refreshButton.implicitWidth
              text: "Model Dock"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            PanelActionButton {
              id: refreshButton
              iconText: "󰑓"
              tooltipText: "Refresh status"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.refresh()
            }
          }
          PanelSeparator { width: parent.width; foreground: root.foreground }
          ModelDockControls { width: parent.width; controller: root }
          Column {
            visible: root.showLegacy
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "EXISTING RUNTIME PROFILES"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.status.profiles || []
              Button {
                required property var modelData
                width: parent.width
                text: modelData.label || modelData.id
                selected: root.status.profile === modelData.id
                enabled: !root.busy && modelData.ready === true
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.runLegacyAction("start", modelData.id)
              }
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Stop existing runtime"
                enabled: root.legacyRunning && !root.busy
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.runLegacyAction("stop")
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Copy its API URL"
                enabled: String(root.status.endpoint || "") !== ""
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.copyEndpoint(true)
              }
            }
          }
        }
      }
    }
  }
}
