import QtQuick
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.odessa2.bing-wallpaper"
  property int lastExitCode: -1
  property string lastError: ""
  property string lastRunAt: ""
  property string market: "auto"
  property string effectiveMarket: "en-US"
  property bool setWallpaper: true
  property var currentImage: null
  property bool settingsReady: false
  property string settingsSource: "defaults"
  property bool legacyConfigurationLoaded: false
  property bool legacyConfigFound: false
  property string legacyMarket: "auto"
  property bool legacySetWallpaper: true
  property string legacyStatusText: ""
  readonly property bool busy: updateProcess.running

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : ""
  readonly property string helperPath: sourceDir !== ""
    ? sourceDir + "/scripts/update-wallpaper"
    : ""

  function validMarket(value) {
    var candidate = String(value || "")
    return candidate === "auto"
      || candidate === "global"
      || /^[a-z]{2}-[A-Z]{2}$/.test(candidate)
  }

  function inlineEntry() {
    var config = shell && shell.shellConfig ? shell.shellConfig : null
    var layout = config && config.bar && config.bar.layout
      ? config.bar.layout
      : null
    if (!layout) return null

    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]]
      if (!entries || typeof entries.length !== "number") continue
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i]
        if (entry && String(entry.id || "") === pluginId) return entry
      }
    }
    return null
  }

  function hasInlineConfiguration(entry) {
    return !!entry && (entry.market !== undefined || entry.setWallpaper !== undefined)
  }

  function applyConfiguration(nextMarket, nextSetWallpaper, source) {
    var normalizedMarket = validMarket(nextMarket) ? String(nextMarket) : "auto"
    var normalizedSetWallpaper = nextSetWallpaper !== false
    var changed = market !== normalizedMarket || setWallpaper !== normalizedSetWallpaper
    market = normalizedMarket
    setWallpaper = normalizedSetWallpaper
    settingsSource = source || settingsSource
    settingsReady = true
    return changed
  }

  function setConfiguration(nextMarket, nextSetWallpaper) {
    applyConfiguration(nextMarket, nextSetWallpaper, "shell")
  }

  function syncConfigurationFromShell() {
    if (helperPath === "" || !shell) return
    var entry = inlineEntry()
    if (hasInlineConfiguration(entry)) {
      var wasReady = settingsReady
      var changed = applyConfiguration(
        entry.market !== undefined ? entry.market : "auto",
        entry.setWallpaper !== undefined ? entry.setWallpaper : true,
        "shell")
      if (wasReady && changed) refresh()
      else loadStatus()
      return
    }

    if (!legacyConfigurationLoaded && !legacyStatusProcess.running) {
      settingsReady = false
      legacyStatusText = ""
      legacyStatusProcess.command = [helperPath, "legacy-status"]
      legacyStatusProcess.running = true
      return
    }

    if (legacyConfigurationLoaded) {
      var wasReady = settingsReady
      var changed = applyConfiguration(
        legacyConfigFound ? legacyMarket : "auto",
        legacyConfigFound ? legacySetWallpaper : true,
        legacyConfigFound ? "legacy" : "defaults")
      if (wasReady && changed) refresh()
      else loadStatus()
    }
  }

  function applyLegacyConfiguration(raw, exitCode) {
    legacyConfigurationLoaded = true
    var nextMarket = "auto"
    var nextSetWallpaper = true
    var source = "defaults"

    if (exitCode === 0) {
      try {
        var data = JSON.parse(String(raw || "{}"))
        if (data.legacyConfigFound === true) {
          nextMarket = data.market
          nextSetWallpaper = data.setWallpaper
          source = "legacy"
          legacyConfigFound = true
        }
        effectiveMarket = String(data.effectiveMarket || effectiveMarket)
        currentImage = data.current || null
      } catch (error) {
        console.warn("bing-wallpaper: invalid legacy status:", error)
      }
    }

    legacyMarket = validMarket(nextMarket) ? String(nextMarket) : "auto"
    legacySetWallpaper = nextSetWallpaper !== false

    if (!hasInlineConfiguration(inlineEntry()))
      applyConfiguration(legacyMarket, legacySetWallpaper, source)
    else
      syncConfigurationFromShell()
  }

  function refresh() {
    if (helperPath === "" || !settingsReady || updateProcess.running) return
    lastError = ""
    updateProcess.command = [
      helperPath,
      "update",
      market,
      setWallpaper ? "true" : "false"
    ]
    updateProcess.running = true
  }

  function loadStatus() {
    if (helperPath === "" || !settingsReady || statusProcess.running) return
    statusProcess.command = [
      helperPath,
      "status",
      market,
      setWallpaper ? "true" : "false"
    ]
    statusProcess.running = true
  }

  function applyStatus(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
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
    id: statusProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: legacyStatusProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.legacyStatusText = String(text || "")
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") console.warn("bing-wallpaper:", message)
      }
    }

    onExited: function(exitCode) {
      root.applyLegacyConfiguration(root.legacyStatusText, exitCode)
    }
  }

  Timer {
    interval: 60 * 60 * 1000
    running: root.helperPath !== "" && root.settingsReady
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Connections {
    target: root.shell
    function onShellConfigChanged() { root.syncConfigurationFromShell() }
  }

  onShellChanged: syncConfigurationFromShell()
  onHelperPathChanged: syncConfigurationFromShell()

  IpcHandler {
    target: "bing-wallpaper"

    function refresh(): string {
      if (!root.settingsReady) return "settings not ready"
      if (updateProcess.running) return "already running"
      root.refresh()
      return "refresh started"
    }

    function status(): string {
      return JSON.stringify({
        running: updateProcess.running,
        market: root.market,
        effectiveMarket: root.effectiveMarket,
        setWallpaper: root.setWallpaper,
        settingsReady: root.settingsReady,
        settingsSource: root.settingsSource,
        currentImage: root.currentImage,
        lastExitCode: root.lastExitCode,
        lastError: root.lastError,
        lastRunAt: root.lastRunAt
      })
    }
  }
}
