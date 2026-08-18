import QtQuick
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property int lastExitCode: -1
  property string lastError: ""
  property string lastRunAt: ""
  property string market: "auto"
  property string effectiveMarket: "en-US"
  property bool setWallpaper: true
  property var currentImage: null
  property var pendingConfiguration: null
  property int configurationRevision: 0
  property int statusConfigurationRevision: -1
  readonly property bool busy: updateProcess.running || configureProcess.running

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : ""
  readonly property string helperPath: sourceDir !== ""
    ? sourceDir + "/scripts/update-wallpaper"
    : ""

  function refresh() {
    if (helperPath === "" || updateProcess.running) return
    lastError = ""
    updateProcess.command = [helperPath]
    updateProcess.running = true
  }

  function configure(nextMarket, nextSetWallpaper) {
    if (helperPath === "") return
    configurationRevision += 1
    market = String(nextMarket)
    setWallpaper = nextSetWallpaper === true
    if (configureProcess.running) {
      pendingConfiguration = { market: market, setWallpaper: setWallpaper }
      return
    }
    runConfiguration(market, setWallpaper)
  }

  function toggleSetWallpaper() {
    configure(market, !setWallpaper)
  }

  function runConfiguration(nextMarket, nextSetWallpaper) {
    configureProcess.command = [helperPath, "configure", String(nextMarket), nextSetWallpaper ? "true" : "false"]
    configureProcess.running = true
  }

  function loadStatus() {
    if (helperPath === "" || statusProcess.running) return
    statusConfigurationRevision = configurationRevision
    statusProcess.command = [helperPath, "status"]
    statusProcess.running = true
  }

  function applyStatus(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (statusConfigurationRevision === configurationRevision) {
        market = String(data.market || "auto")
        setWallpaper = data.setWallpaper !== false
      }
      effectiveMarket = String(data.effectiveMarket || "en-US")
      currentImage = data.current || null
    } catch (error) {
      console.warn("bing-wallpaper: invalid status:", error)
    }
  }

  Process {
    id: updateProcess

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastError = String(text || "").trim()
    }

    onExited: function(exitCode) {
      root.lastExitCode = exitCode
      root.lastRunAt = new Date().toISOString()
      if (exitCode !== 0 && root.lastError !== "")
        console.warn("bing-wallpaper:", root.lastError)
      root.loadStatus()
    }
  }

  Process {
    id: configureProcess

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastError = String(text || "").trim()
    }

    onExited: function(exitCode) {
      if (root.pendingConfiguration) {
        var next = root.pendingConfiguration
        root.pendingConfiguration = null
        root.runConfiguration(next.market, next.setWallpaper)
      } else if (exitCode === 0) {
        root.refresh()
      } else {
        if (root.lastError !== "")
          console.warn("bing-wallpaper:", root.lastError)
        root.loadStatus()
      }
    }
  }

  Process {
    id: statusProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Timer {
    interval: 60 * 60 * 1000
    running: root.helperPath !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onHelperPathChanged: if (helperPath !== "") loadStatus()

  IpcHandler {
    target: "bing-wallpaper"

    function refresh(): string {
      if (updateProcess.running) return "already running"
      root.refresh()
      return "refresh started"
    }

    function status(): string {
      return JSON.stringify({
        running: updateProcess.running,
        configuring: configureProcess.running,
        market: root.market,
        effectiveMarket: root.effectiveMarket,
        setWallpaper: root.setWallpaper,
        currentImage: root.currentImage,
        lastExitCode: root.lastExitCode,
        lastError: root.lastError,
        lastRunAt: root.lastRunAt
      })
    }
  }
}
