pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    readonly property Process dlCheckProc: Process {
        property int exitCode: -1

        onExited: code => {
            dlCheckProc.exitCode = code;
        }

        stdout: SplitParser {
            onRead: {}
        }
    }

    property string thumbUrl: ""
    property string fullUrl: ""
    property string wallId: ""
    property string resolution: ""
    property bool skeleton: false
    property bool downloaded: false
    property int provider: 0
    property string slug: ""

    onFullUrlChanged: dlCheckTimer.restart()
    onWallIdChanged: dlCheckTimer.restart()
    onSlugChanged: dlCheckTimer.restart()

    Timer {
        id: dlCheckTimer
        interval: 50
        onTriggered: root.checkDownloaded()
    }

    function checkDownloaded() {
        if (root.provider === 1) {
            if (!root.slug) return;
            const safeName = root.slug.replace(/[@/\\:*?"<>|]/g, "_");
            const patterns = [
                Paths.wallsdir + "/" + safeName + "_4K.jpg",
                Paths.wallsdir + "/" + safeName + "_2K.jpg",
                Paths.wallsdir + "/" + safeName + "_HD.jpg",
                Paths.wallsdir + "/" + safeName + "_thumb.jpg"
            ];
            dlCheckProc.exitCode = -1;
            dlCheckProc.command = ["sh", "-c", `test -f "${patterns[0]}" || test -f "${patterns[1]}" || test -f "${patterns[2]}" || test -f "${patterns[3]}"`];
            dlCheckProc.running = true;
        } else {
            if (!root.wallId || !root.fullUrl) return;
            const filename = root.fullUrl.split("/").pop().split("?")[0];
            const pathA = Paths.wallsdir + "/" + filename;
            const pathB = Paths.wallsdir + "/" + root.wallId + "." + filename.split(".").pop();
            dlCheckProc.exitCode = -1;
            dlCheckProc.command = ["sh", "-c", `test -f "${pathA}" || test -f "${pathB}"`];
            dlCheckProc.running = true;
        }
    }

    Connections {
        target: dlCheckProc
        function onRunningChanged() {
            if (!dlCheckProc.running && !root.downloaded)
                root.downloaded = dlCheckProc.exitCode === 0;
        }
    }

    Connections {
        target: WallhavenService.downloadProc
        function onRunningChanged() {
            if (!WallhavenService.downloadProc.running && !root.downloaded)
                root.checkDownloaded();
        }
    }

    Connections {
        target: WallhavenService.downloadSetProc
        function onRunningChanged() {
            if (!WallhavenService.downloadSetProc.running && !root.downloaded)
                root.checkDownloaded();
        }
    }

    Connections {
        target: UhdService.downloadProc
        function onRunningChanged() {
            if (!UhdService.downloadProc.running && !root.downloaded)
                root.checkDownloaded();
        }
    }

    Connections {
        target: UhdService.downloadSetProc
        function onRunningChanged() {
            if (!UhdService.downloadSetProc.running && !root.downloaded)
                root.checkDownloaded();
        }
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    Layout.minimumHeight: width * 0.625 + (root.skeleton ? 0 : 20)

    ColumnLayout {
        id: col

        anchors.fill: parent
        spacing: Tokens.spacing.small

        StyledClippingRect {
            id: imgWrapper

            Layout.fillWidth: true
            implicitHeight: width * 0.625
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            // Skeleton shimmer
            Loader {
                anchors.fill: parent
                active: root.skeleton
                visible: active

                sourceComponent: Item {
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.darker(Colours.tPalette.m3surfaceContainer, 1.05)
                        radius: imgWrapper.radius
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: parent.height * 0.5
                        radius: imgWrapper.radius
                        color: Qt.rgba(1, 1, 1, 0.04)

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            PropertyAnimation {
                                from: 0.3
                                to: 0.8
                                duration: 1000
                                easing.type: Easing.InOutQuad
                            }
                            PropertyAnimation {
                                from: 0.8
                                to: 0.3
                                duration: 1000
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }

            // Loading spinner
            Loader {
                anchors.centerIn: parent
                opacity: img.status === Image.Ready || root.skeleton ? 0 : 1
                active: opacity > 0

                sourceComponent: StyledRect {
                    implicitWidth: loadingIndicator.implicitSize + Tokens.padding.large * 2
                    implicitHeight: loadingIndicator.implicitSize + Tokens.padding.large * 2
                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: loadingIndicator
                        anchors.centerIn: parent
                        containsIcon: true
                        implicitSize: Math.min(imgWrapper.width, imgWrapper.height) * 0.25
                    }
                }

                Behavior on opacity {
                    Anim { type: Anim.DefaultEffects }
                }
            }

            Image {
                id: img

                anchors.fill: parent
                asynchronous: true
                smooth: false
                mipmap: false
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(400, 400)
                cache: true
                retainWhileLoading: true
                opacity: root.skeleton ? 0 : (status === Image.Ready ? 1 : 0)
                source: root.thumbUrl

                Behavior on opacity {
                    Anim { type: Anim.SlowEffects }
                }
            }

            // Hover overlay
            Item {
                anchors.fill: parent
                opacity: hoverHandler.hovered && !root.skeleton ? 1 : 0

                Behavior on opacity {
                    Anim { type: Anim.DefaultEffects }
                }

                StyledRect {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.55)
                    radius: imgWrapper.radius
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.medium

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing.medium

                        IconButton {
                            id: applyBtn
                            icon: "wallpaper"
                            type: IconButton.Filled
                            isRound: true
                            onClicked: {
                                clickAnim1.start();
                                root.downloaded = true;
                                if (root.provider === 1)
                                    UhdService.downloadAndSet(root.slug);
                                else
                                    WallhavenService.downloadAndSet(root.wallId, root.fullUrl);
                            }

                            SequentialAnimation {
                                id: clickAnim1
                                NumberAnimation { target: applyBtn; property: "scale"; to: 0.8; duration: 80; easing.type: Easing.OutQuad }
                                NumberAnimation { target: applyBtn; property: "scale"; to: 1; duration: 150; easing.type: Easing.OutElastic }
                            }
                        }

                        IconButton {
                            id: downloadBtn
                            icon: root.downloaded ? "check" : "download"
                            type: root.downloaded ? IconButton.Tonal : IconButton.Filled
                            isRound: true
                            disabled: root.downloaded
                            onClicked: {
                                if (!root.downloaded) {
                                    clickAnim2.start();
                                    root.downloaded = true;
                                    if (root.provider === 1)
                                        UhdService.downloadToLibrary(root.slug);
                                    else
                                        WallhavenService.downloadToLibrary(root.wallId, root.fullUrl);
                                }
                            }

                            SequentialAnimation {
                                id: clickAnim2
                                NumberAnimation { target: downloadBtn; property: "scale"; to: 0.8; duration: 80; easing.type: Easing.OutQuad }
                                NumberAnimation { target: downloadBtn; property: "scale"; to: 1; duration: 150; easing.type: Easing.OutElastic }
                            }
                        }

                        IconButton {
                            id: openBtn
                            icon: "open_in_new"
                            type: IconButton.Filled
                            isRound: true
                            onClicked: {
                                clickAnim3.start();
                                Qt.openUrlExternally(root.fullUrl)
                            }

                            SequentialAnimation {
                                id: clickAnim3
                                NumberAnimation { target: openBtn; property: "scale"; to: 0.8; duration: 80; easing.type: Easing.OutQuad }
                                NumberAnimation { target: openBtn; property: "scale"; to: 1; duration: 150; easing.type: Easing.OutElastic }
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !!root.resolution
                        text: root.resolution
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font: Tokens.font.label.small
                    }
                }
            }

            HoverHandler {
                id: hoverHandler
            }

            // Downloaded badge
            StyledRect {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.padding.small
                width: badgeRow.implicitWidth + Tokens.padding.small * 2
                height: badgeRow.implicitHeight + Tokens.padding.extraSmall
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
                visible: root.downloaded && !root.skeleton
                opacity: hoverHandler.hovered ? 0 : 0.9

                Behavior on opacity {
                    Anim { type: Anim.DefaultEffects }
                }

                RowLayout {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: Tokens.padding.extraSmall

                    MaterialIcon {
                        text: "check"
                        color: Colours.palette.m3onPrimary
                        fontStyle: Tokens.font.icon.extraSmall
                    }

                    StyledText {
                        text: qsTr("Downloaded")
                        color: Colours.palette.m3onPrimary
                        font: Tokens.font.label.small
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.padding.extraSmall
            visible: !root.skeleton

            MaterialIcon {
                text: "aspect_ratio"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.extraSmall
            }

            StyledText {
                Layout.fillWidth: true
                text: root.resolution || "#" + root.wallId
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }
    }
}
