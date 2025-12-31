pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: card.implicitHeight + Appearance.sizes.elevationMargin
    visible: Wallpapers.wallpapers.length > 0

    readonly property real cardPadding: 12
    readonly property real itemSpacing: 8
    readonly property real itemWidth: 130
    readonly property real itemHeight: 78  // ~16:10 aspect
    readonly property bool showHeader: Config.options?.sidebar?.widgets?.quickWallpaper?.showHeader ?? true

    Component.onCompleted: Wallpapers.load()

    StyledRectangularShadow { target: card; visible: !Appearance.inirEverywhere && !Appearance.auroraEverywhere }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width
        implicitHeight: mainColumn.implicitHeight + (root.cardPadding * 2)
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? "transparent" 
             : Appearance.colors.colLayer1
        border.width: Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: root.cardPadding
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.showHeader

                MaterialSymbol {
                    text: "wallpaper"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.inirEverywhere ? Appearance.inir.colSubtext : Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Wallpapers")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.inirEverywhere ? Appearance.inir.colSubtext : Appearance.colors.colSubtext
                    Layout.fillWidth: true
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                        : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
                        : Appearance.colors.colLayer2Active
                    onClicked: Wallpapers.randomFromCurrentFolder()
                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "casino"
                            iconSize: 16
                            color: Appearance.inirEverywhere ? Appearance.inir.colSubtext : Appearance.colors.colSubtext
                        }
                    }
                    StyledToolTip { text: Translation.tr("Random wallpaper") }
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                        : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
                        : Appearance.colors.colLayer2Active
                    onClicked: GlobalStates.wallpaperSelectorOpen = true
                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "open_in_full"
                            iconSize: 16
                            color: Appearance.inirEverywhere ? Appearance.inir.colSubtext : Appearance.colors.colSubtext
                        }
                    }
                    StyledToolTip { text: Translation.tr("Open wallpaper selector") }
                }
            }

            // Carousel
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.itemHeight

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: carousel.width
                        height: carousel.height
                        radius: Appearance.rounding.small
                    }
                }

                ScrollEdgeFade {
                    z: 1
                    target: carousel
                    vertical: false
                    fadeSize: 24
                }

                ListView {
                    id: carousel
                    anchors.centerIn: parent
                    width: parent.width
                    height: root.itemHeight
                    orientation: ListView.Horizontal
                    spacing: root.itemSpacing
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            carousel.contentX = Math.max(0, Math.min(
                                carousel.contentWidth - carousel.width,
                                carousel.contentX - delta
                            ))
                        }
                    }

                    model: Wallpapers.wallpapers

                    delegate: Item {
                        id: wallpaperDelegate
                        required property int index
                        required property string modelData
                        readonly property string filePath: modelData
                        readonly property bool isCurrentWallpaper: (Config.options?.background?.wallpaperPath ?? "") === filePath
                        readonly property bool isHovered: mouseArea.containsMouse

                        width: root.itemWidth
                        height: root.itemHeight

                        // Selection ring (inside, as border)
                        Rectangle {
                            anchors.fill: parent
                            radius: thumb.radius
                            color: "transparent"
                            border.width: wallpaperDelegate.isCurrentWallpaper ? 2 : 0
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                            z: 2

                            Behavior on border.width { NumberAnimation { duration: 150 } }
                        }

                        Rectangle {
                            id: thumb
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.colors.colLayer2

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: thumb.width
                                    height: thumb.height
                                    radius: thumb.radius
                                }
                            }

                            ThumbnailImage {
                                anchors.fill: parent
                                sourcePath: wallpaperDelegate.filePath
                                fallbackToDownscaledSource: true
                                fillMode: Image.PreserveAspectCrop
                            }

                            // Hover overlay
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: wallpaperDelegate.isHovered && !wallpaperDelegate.isCurrentWallpaper
                                    ? ColorUtils.transparentize("#000000", 0.7)
                                    : "transparent"
                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                            }

                            // Check icon for selected
                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: Appearance.colors.colPrimary
                                visible: wallpaperDelegate.isCurrentWallpaper
                                scale: wallpaperDelegate.isCurrentWallpaper ? 1 : 0

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: 18
                                    color: Appearance.colors.colOnPrimary
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.select(wallpaperDelegate.filePath)
                            }
                        }
                    }
                }
            }
        }
    }
}
