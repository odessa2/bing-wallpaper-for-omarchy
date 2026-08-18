import QtQuick
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property int lastExitCode: -1
  property string lastError: ""
  property string lastRunAt: ""

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
    }
  }

  Timer {
    interval: 60 * 60 * 1000
    running: root.helperPath !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

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
        lastExitCode: root.lastExitCode,
        lastError: root.lastError,
        lastRunAt: root.lastRunAt
      })
    }
  }
}
