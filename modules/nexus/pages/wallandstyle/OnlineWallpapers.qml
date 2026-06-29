pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Online wallpapers")
    isSubPage: true

    readonly property var wh: WallhavenService
    readonly property var uhd: UhdService

    property int selProvider: 0

    readonly property var catLabels: [qsTr("General"), qsTr("Anime"), qsTr("People")]
    readonly property var catBits: ["100", "010", "001"]
    property int selCat: -1

    readonly property var purLabels: [qsTr("SFW"), qsTr("Sketchy"), qsTr("NSFW")]
    readonly property var purBits: ["100", "010", "001"]
    property int selPur: 0

    readonly property var sortLabels: [qsTr("Relevance"), qsTr("Random"), qsTr("Date added"), qsTr("Favorites"), qsTr("Top list"), qsTr("Views"), qsTr("Top range")]
    readonly property var sortBits: ["relevance", "random", "date_added", "favorites", "toplist", "views", ""]
    property int selSort: 2

    readonly property var resLabels: [qsTr("Any"), qsTr("720p+"), qsTr("1080p+"), qsTr("1440p+"), qsTr("4K+"), qsTr("5K+"), qsTr("8K+")]
    readonly property var resBits: ["", "1280x720", "1920x1080", "2560x1440", "3840x2160", "5120x2880", "7680x4320"]
    property int selRes: 0

    readonly property var ratioLabels: [qsTr("Any"), qsTr("16:9"), qsTr("16:10"), qsTr("4:3"), qsTr("21:9"), qsTr("32:9"), qsTr("9:16")]
    readonly property var ratioBits: ["", "16x9", "16x10", "4x3", "21x9", "32x9", "9x16"]
    property int selRatio: 0

    readonly property var colorHexes: ["", "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff"]
    property string selColor: ""

    property string searchQuery: ""
    property string tagQuery: ""
    property string inputApiKey: wh.apiKey
    property bool filtersExpanded: false
    property bool settingsExpanded: false
    property int selUhdCat: -1
    property int selUhdRes: -1

    readonly property var uhdResLabels: [qsTr("Any"), qsTr("4K"), qsTr("2K"), qsTr("1080p")]
    readonly property var uhdResValues: ["", "3840x2160", "2560x1440", "1920x1080"]

    readonly property var currentService: selProvider === 0 ? wh : uhd
    readonly property bool isLoading: selProvider === 0 ? wh.loading : uhd.loading
    readonly property var currentWallpapers: selProvider === 0 ? wh.wallpapers : uhd.wallpapers
    readonly property int currentPageNum: selProvider === 0 ? wh.currentPage : uhd.currentPage
    readonly property int lastPageNum: selProvider === 0 ? wh.lastPage : uhd.lastPage
    readonly property int totalResultsNum: selProvider === 0 ? wh.totalResults : uhd.totalResults

    Component.onCompleted: {
        syncFromService();
        doSearch();
    }

    function syncFromService() {
        searchQuery = wh.query;
        tagQuery = wh.tags;
        inputApiKey = wh.apiKey;
        const ci = catBits.indexOf(wh.categories);
        selCat = ci >= 0 ? ci : -1;
        const pi = purBits.indexOf(wh.purity);
        selPur = pi >= 0 ? pi : 0;
        const si = sortBits.indexOf(wh.sorting);
        selSort = si >= 0 ? si : 2;
        const ri = resBits.indexOf(wh.atleast);
        selRes = ri >= 0 ? ri : 0;
        selColor = wh.colors;
    }

    function doSearch() {
        if (selProvider === 0) {
            wh.resetAndSearch(
                searchQuery,
                selCat === -1 ? "111" : catBits[selCat],
                purBits[selPur],
                sortBits[selSort],
                resBits[selRes],
                selColor,
                ratioBits[selRatio],
                tagQuery
            );
        } else {
            const catKey = selUhdCat >= 0 ? uhd.categoryKeys[selUhdCat] : "";
            uhd.search(catKey || searchQuery, uhdResValues[selUhdRes] || "");
        }
    }

    function goToPage(page) {
        if (selProvider === 0)
            wh.goToPage(page);
        else
            uhd.goToPage(page);
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: (root.width - root.cappedWidth) / 2
        Layout.rightMargin: Layout.leftMargin
        spacing: Tokens.spacing.extraSmall / 2

        // Provider selector
        ConnectedRect {
            first: true
            Layout.fillWidth: true
            implicitHeight: providerRow.implicitHeight + providerRow.anchors.margins * 2

            RowLayout {
                id: providerRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                Repeater {
                    model: [qsTr("Wallhaven"), qsTr("uhdpaper")]

                    ToggleButton {
                        required property int index
                        required property string modelData

                        Layout.fillWidth: true
                        toggled: index === root.selProvider
                        label: modelData
                        icon: index === 0 ? "image" : "landscape"
                        accent: "Primary"
                        onClicked: {
                            root.selProvider = index;
                            root.doSearch();
                        }
                    }
                }
            }
        }

        // Search bar
        ConnectedRect {
            last: root.selProvider !== 0 || !root.filtersExpanded
            Layout.fillWidth: true
            implicitHeight: searchRow.implicitHeight + searchRow.anchors.margins * 2

            RowLayout {
                id: searchRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                StyledTextField {
                    id: searchField

                    Layout.fillWidth: true
                    placeholderText: root.selProvider === 0 ? qsTr("Search wallpapers...") : qsTr("Search wallpapers...")
                    text: root.searchQuery
                    onEditingFinished: {
                        root.searchQuery = text;
                        if (root.selProvider === 1 && text)
                            root.selUhdCat = -1;
                        root.doSearch();
                    }
                }

                IconButton {
                    icon: "tune"
                    type: IconButton.Tonal
                    isRound: true
                    checked: root.filtersExpanded
                    visible: root.selProvider === 0
                    onClicked: root.filtersExpanded = !root.filtersExpanded
                }
            }
        }

        // UHD-only: Category + Resolution filters
        ConnectedRect {
            visible: root.selProvider === 1
            last: true
            Layout.fillWidth: true
            implicitHeight: uhdFiltersCol.implicitHeight + uhdFiltersCol.anchors.margins * 2

            ColumnLayout {
                id: uhdFiltersCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: uhd.categoryLabels.length + 1

                        ToggleButton {
                            required property int index

                            toggled: index === 0 ? root.selUhdCat === -1 : root.selUhdCat === index - 1
                            label: index === 0 ? qsTr("All") : uhd.categoryLabels[index - 1]
                            accent: "Primary"
                            iconSize: Tokens.font.icon.small.pointSize
                            horizontalPadding: Tokens.padding.small
                            verticalPadding: Tokens.padding.extraSmall / 2
                            onClicked: {
                                root.selUhdCat = index === 0 ? -1 : index - 1;
                                if (root.selUhdCat >= 0) {
                                    root.searchQuery = "";
                                    searchField.text = "";
                                }
                                root.doSearch();
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.uhdResLabels.length

                        ToggleButton {
                            required property int index

                            toggled: index === 0 ? root.selUhdRes === -1 : root.selUhdRes === index - 1
                            label: root.uhdResLabels[index]
                            accent: "Secondary"
                            iconSize: Tokens.font.icon.small.pointSize
                            horizontalPadding: Tokens.padding.small
                            verticalPadding: Tokens.padding.extraSmall / 2
                            onClicked: {
                                root.selUhdRes = index === 0 ? -1 : index - 1;
                                root.doSearch();
                            }
                        }
                    }
                }
            }
        }

        // Wallhaven-only: Category + Purity
        ConnectedRect {
            visible: root.selProvider === 0
            last: !root.filtersExpanded || root.selProvider !== 0
            Layout.fillWidth: true
            implicitHeight: catPurCol.implicitHeight + catPurCol.anchors.margins * 2

            ColumnLayout {
                id: catPurCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.catLabels.length + 1

                        ToggleButton {
                            required property int index

                            toggled: index === 0 ? root.selCat === -1 : root.selCat === index - 1
                            label: index === 0 ? qsTr("All") : root.catLabels[index - 1]
                            icon: index === 0 ? "grid_view" : index === 1 ? "image" : index === 2 ? "animation" : "person"
                            accent: "Primary"
                            iconSize: Tokens.font.icon.small.pointSize
                            horizontalPadding: Tokens.padding.small
                            verticalPadding: Tokens.padding.extraSmall / 2
                            onClicked: {
                                root.selCat = index === 0 ? -1 : index - 1;
                                root.doSearch();
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.purLabels.length

                        ToggleButton {
                            required property int index

                            toggled: index === root.selPur
                            label: root.purLabels[index]
                            icon: index === 0 ? "shield" : index === 1 ? "warning" : "no_adult_content"
                            accent: "Secondary"
                            iconSize: Tokens.font.icon.small.pointSize
                            horizontalPadding: Tokens.padding.small
                            verticalPadding: Tokens.padding.extraSmall / 2
                            onClicked: {
                                root.selPur = index;
                                root.doSearch();
                            }
                        }
                    }
                }
            }
        }

        // Wallhaven-only: Expanded filters
        ConnectedRect {
            Layout.fillWidth: true
            visible: root.selProvider === 0 && root.filtersExpanded
            implicitHeight: expandedCol.implicitHeight + expandedCol.anchors.margins * 2

            ColumnLayout {
                id: expandedCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Sort by")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: root.sortLabels.length

                            ToggleButton {
                                required property int index

                                toggled: index === root.selSort
                                label: root.sortLabels[index]
                                accent: "Secondary"
                                iconSize: Tokens.font.icon.small.pointSize
                                horizontalPadding: Tokens.padding.small
                                verticalPadding: Tokens.padding.extraSmall / 2
                                onClicked: {
                                    root.selSort = index;
                                    root.doSearch();
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Min resolution")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: root.resLabels.length

                            ToggleButton {
                                required property int index

                                toggled: index === root.selRes
                                label: root.resLabels[index]
                                accent: "Secondary"
                                iconSize: Tokens.font.icon.small.pointSize
                                horizontalPadding: Tokens.padding.small
                                verticalPadding: Tokens.padding.extraSmall / 2
                                onClicked: {
                                    root.selRes = index;
                                    root.doSearch();
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Aspect ratio")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: root.ratioLabels.length

                            ToggleButton {
                                required property int index

                                toggled: index === root.selRatio
                                label: root.ratioLabels[index]
                                accent: "Secondary"
                                iconSize: Tokens.font.icon.small.pointSize
                                horizontalPadding: Tokens.padding.small
                                verticalPadding: Tokens.padding.extraSmall / 2
                                onClicked: {
                                    root.selRatio = index;
                                    root.doSearch();
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Color")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: root.colorHexes

                            StyledRect {
                                required property var modelData
                                required property int index

                                width: 28
                                height: 28
                                radius: Tokens.rounding.full
                                color: modelData === "" ? Colours.tPalette.m3surfaceContainer : "#" + modelData
                                border.width: root.selColor === modelData ? 2 : 0
                                border.color: Colours.palette.m3primary

                                StateLayer {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Colours.palette.m3onSurface
                                    onClicked: {
                                        root.selColor = modelData;
                                        root.doSearch();
                                    }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: modelData === ""
                                    text: "close"
                                    color: Colours.palette.m3outline
                                    fontStyle: Tokens.font.icon.extraSmall
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Tags")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("landscape, nature, dark")
                        text: root.tagQuery
                        onEditingFinished: {
                            root.tagQuery = text;
                            root.doSearch();
                        }
                    }
                }
            }
        }

        // Wallhaven-only: API Key
        ConnectedRect {
            Layout.fillWidth: true
            visible: root.selProvider === 0
            implicitHeight: apiKeyCol.implicitHeight + apiKeyCol.anchors.margins * 2

            ColumnLayout {
                id: apiKeyCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "key"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("API Key")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        text: qsTr("Wallhaven")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://wallhaven.cc/settings/account")
                        }
                    }

                    MaterialIcon {
                        text: "expand_more"
                        rotation: root.settingsExpanded ? 180 : 0
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small

                        Behavior on rotation {
                            Anim { type: Anim.StandardSmall }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.settingsExpanded = !root.settingsExpanded
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.settingsExpanded
                    spacing: Tokens.spacing.small

                    StyledTextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("Paste API key for NSFW content...")
                        text: root.inputApiKey
                        echoMode: TextInput.Password
                        onEditingFinished: {
                            root.inputApiKey = text;
                            wh.apiKey = text;
                            wh.saveState();
                        }
                    }

                    IconButton {
                        icon: "save"
                        type: IconButton.Filled
                        isRound: true
                        onClicked: {
                            wh.apiKey = root.inputApiKey;
                            wh.saveState();
                            root.doSearch();
                        }
                    }
                }
            }
        }

        // Results info + pagination
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.isLoading ? qsTr("Searching...") : qsTr("%1 wallpapers").arg(root.totalResultsNum)
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }

            IconButton {
                icon: "chevron_left"
                type: IconButton.Tonal
                disabled: root.currentPageNum <= 1 || root.isLoading
                onClicked: root.goToPage(root.currentPageNum - 1)
            }

            StyledText {
                text: qsTr("%1 / %2").arg(root.currentPageNum).arg(root.lastPageNum)
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            IconButton {
                icon: "chevron_right"
                type: IconButton.Tonal
                disabled: root.currentPageNum >= root.lastPageNum || root.isLoading
                onClicked: root.goToPage(root.currentPageNum + 1)
            }
        }

        // Wallpaper Grid
        GridLayout {
            Layout.fillWidth: true
            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.small
            columnSpacing: Tokens.spacing.small

            Repeater {
                model: root.isLoading && root.currentWallpapers.length === 0 ? Config.nexus.wallpapersPerRow : 0

                WallItemOnline {
                    Layout.fillWidth: true
                    skeleton: true
                }
            }

            Repeater {
                model: root.currentWallpapers

                WallItemOnline {
                    required property var modelData

                    provider: root.selProvider
                    thumbUrl: modelData.thumbs?.medium ?? modelData.thumbs?.small ?? ""
                    fullUrl: modelData.path ?? ""
                    wallId: modelData.id ?? ""
                    slug: modelData.slug ?? ""
                    resolution: modelData.resolution ?? ""
                }
            }
        }

        // Loading indicator (Wallhaven only)
        Loader {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            active: root.selProvider === 0 && root.isLoading && root.currentWallpapers.length > 0
            visible: active

            sourceComponent: RowLayout {
                spacing: Tokens.spacing.small

                Item {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14

                    LoadingIndicator {
                        anchors.fill: parent
                        containsIcon: true
                        implicitSize: 14
                    }
                }

                StyledText {
                    text: qsTr("Loading...")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }
        }

        // Empty state
        Loader {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraLarge
            active: !root.isLoading && root.currentWallpapers.length === 0
            visible: active

            sourceComponent: StyledRect {
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.extraLarge
                implicitHeight: emptyCol.implicitHeight + Tokens.padding.extraExtraLarge * 2

                ColumnLayout {
                    id: emptyCol

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "search_off"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No wallpapers found")
                        color: Colours.palette.m3outline
                        font: Tokens.font.title.small
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Try different search terms or adjust filters")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.medium
                    }
                }
            }
        }
    }
}
