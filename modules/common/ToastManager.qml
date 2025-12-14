import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root
    
    // Toast queue
    property var toasts: []
    property int maxToasts: 5
    property int toastSpacing: 8
    
    // Debounce tracking for reload toasts
    property real _lastQsReloadTime: 0
    property real _lastNiriReloadTime: 0
    property bool _qsReloadPending: false
    property bool _niriReloadPending: false
    readonly property int _reloadDebounceMs: 500  // Coalesce reloads within this window
    
    // Check if reload toasts should be shown - evaluated fresh each time
    function shouldShowReloadToast(): bool {
        // Global disable
        if (!(Config.options?.reloadToasts?.enable ?? true)) return false
        
        // Suppress if disableReloadToasts is enabled AND (GameMode active OR any fullscreen window exists)
        const disableInGameMode = Config.options?.gameMode?.disableReloadToasts ?? true
        if (disableInGameMode && (GameMode.active || GameMode.hasAnyFullscreenWindow || GameMode.suppressNiriToast)) {
            return false
        }
        
        return true
    }
    
    function addToast(title, message, icon, isError, duration, source, accentColor) {
        // Prevent duplicates: if same source already has a toast, ignore
        if (toasts.some(t => t.source === source && t.isError === isError)) {
            return
        }
        
        const toast = {
            id: Date.now(),
            title: title,
            message: message || "",
            icon: icon || (isError ? "error" : "check_circle"),
            isError: isError || false,
            duration: duration || (isError ? 6000 : 2000),
            source: source || "system",
            accentColor: accentColor || Appearance.colors.colPrimary
        }
        
        toasts = [...toasts, toast]
        
        // Limit max toasts
        if (toasts.length > maxToasts) {
            toasts = toasts.slice(-maxToasts)
        }
        
        popupLoader.loading = true
    }
    
    function removeToast(id) {
        toasts = toasts.filter(t => t.id !== id)
        if (toasts.length === 0) {
            popupLoader.active = false
        }
    }
    
    // Debounce timer for Quickshell reload toast
    Timer {
        id: qsReloadDebounce
        interval: root._reloadDebounceMs
        onTriggered: {
            if (root._qsReloadPending) {
                root._qsReloadPending = false
                if (!root.shouldShowReloadToast()) return
                root.addToast(
                    "Quickshell reloaded",
                    "",
                    "refresh",
                    false,
                    2000,
                    "quickshell",
                    Appearance.colors.colPrimary
                )
            }
        }
    }
    
    // Debounce timer for Niri reload toast
    Timer {
        id: niriReloadDebounce
        interval: root._reloadDebounceMs
        onTriggered: {
            if (root._niriReloadPending) {
                root._niriReloadPending = false
                // Only show if Quickshell didn't just reload (QML change triggers both)
                const now = Date.now()
                if (now - root._lastQsReloadTime < root._reloadDebounceMs) {
                    // Quickshell just reloaded, skip Niri toast (it's a false positive)
                    return
                }
                if (!root.shouldShowReloadToast()) return
                root.addToast(
                    "Niri config reloaded",
                    "",
                    "settings",
                    false,
                    2000,
                    "niri",
                    Appearance.colors.colTertiary
                )
            }
        }
    }

    // Quickshell reload signals
    Connections {
        target: Quickshell
        
        function onReloadCompleted() {
            const now = Date.now()
            // Ignore if we just processed a reload
            if (now - root._lastQsReloadTime < root._reloadDebounceMs) {
                return
            }
            root._lastQsReloadTime = now
            root._qsReloadPending = true
            qsReloadDebounce.restart()
        }
        
        function onReloadFailed(error) {
            // Always show errors immediately
            root.addToast(
                "Quickshell reload failed",
                error,
                "error",
                true,
                8000,
                "quickshell",
                Appearance.colors.colError
            )
        }
    }
    
    // Niri config reload signals
    Connections {
        target: NiriService
        
        function onConfigLoadFinished(ok, error) {
            if (ok) {
                const now = Date.now()
                // Ignore if we just processed a reload
                if (now - root._lastNiriReloadTime < root._reloadDebounceMs) {
                    return
                }
                root._lastNiriReloadTime = now
                root._niriReloadPending = true
                niriReloadDebounce.restart()
            } else {
                // Always show errors immediately
                root.addToast(
                    "Niri config reload failed",
                    error || "Run 'niri validate' in terminal for details",
                    "error",
                    true,
                    8000,
                    "niri",
                    Appearance.colors.colError
                )
            }
        }
    }
    
    LazyLoader {
        id: popupLoader
        
        PanelWindow {
            id: popup
            exclusiveZone: 0
            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: 10
            
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:toast-manager"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            // Only capture input on actual toast area
            mask: Region {
                item: toastColumn
            }
            
            implicitHeight: toastColumn.implicitHeight + 20
            color: "transparent"
            
            ColumnLayout {
                id: toastColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: root.toastSpacing
                
                Repeater {
                    model: root.toasts
                    
                    delegate: ToastNotification {
                        required property var modelData
                        required property int index
                        
                        title: modelData.title
                        message: modelData.message
                        icon: modelData.icon
                        isError: modelData.isError
                        duration: modelData.duration
                        source: modelData.source
                        accentColor: modelData.accentColor
                        
                        opacity: 1
                        scale: 1
                        
                        // Entry animation
                        Component.onCompleted: {
                            if (Appearance.animationsEnabled) {
                                entryAnim.start()
                            }
                        }
                        
                        ParallelAnimation {
                            id: entryAnim
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: parent
                                property: "scale"
                                from: 0.9
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        onDismissed: {
                            if (Appearance.animationsEnabled) {
                                exitAnim.start()
                            } else {
                                root.removeToast(modelData.id)
                            }
                        }
                        
                        ParallelAnimation {
                            id: exitAnim
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                to: 0
                                duration: 150
                                easing.type: Easing.InCubic
                            }
                            NumberAnimation {
                                target: parent
                                property: "scale"
                                to: 0.9
                                duration: 150
                                easing.type: Easing.InCubic
                            }
                            onFinished: root.removeToast(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
