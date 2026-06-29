pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.utils

QtObject {
    id: root

    property var wallpapers: []
    property bool loading: false
    property string keyword: ""
    property string resolution: ""
    property int currentPage: 1
    property int lastPage: 1
    property int totalResults: 0
    property int perPage: 20

    property var _allResults: []
    property var _filteredResults: []
    property string _tmpJson: `${Paths.cache}/uhd_results.json`

    readonly property string scriptDir: `${Quickshell.shellDir}/scripts/webWallpaper/uhdpaper`
    readonly property string scriptPath: `${scriptDir}/main.py`

    readonly property var categoryKeys: ["game", "anime", "movie", "series", "abstract", "animals", "celebrity", "comics", "digitalart", "fantasy", "nature", "scenery", "scifi", "space"]
    readonly property var categoryLabels: [qsTr("Game"), qsTr("Anime"), qsTr("Movie"), qsTr("Series"), qsTr("Abstract"), qsTr("Animals"), qsTr("Celebrity"), qsTr("Comics"), qsTr("Digital Art"), qsTr("Fantasy"), qsTr("Nature"), qsTr("Scenery"), qsTr("Sci-Fi"), qsTr("Space")]

    function search(query, res) {
        keyword = query ?? "";
        resolution = res ?? "";
        currentPage = 1;
        _fetch();
    }

    function goToPage(page) {
        if (page < 1 || page > lastPage) return;
        currentPage = page;
        _applyPage();
    }

    function _applyPage() {
        if (resolution) {
            _filteredResults = _allResults.filter(function(w) {
                return w.resolution === resolution;
            });
        } else {
            _filteredResults = _allResults;
        }
        totalResults = _filteredResults.length;
        lastPage = Math.max(1, Math.ceil(totalResults / perPage));
        if (currentPage > lastPage) currentPage = lastPage;
        const start = (currentPage - 1) * perPage;
        const end = start + perPage;
        wallpapers = _filteredResults.slice(start, end);
    }

    function _fetch() {
        loading = true;
        let cmd = `python3 "${scriptPath}" --json --list --pages 10`;
        if (keyword)
            cmd += ` --keyword "${keyword}"`;
        cmd += ` > "${_tmpJson}" 2>/dev/null`;
        fetchProc.command = ["sh", "-c", cmd];
        fetchProc.running = true;
    }

    function downloadAndSet(slug) {
        Quickshell.execDetached(["mkdir", "-p", Paths.wallsdir]);
        downloadSetProc.command = ["sh", "-c", `cd "${scriptDir}" && python3 main.py --slug "${slug}" --output "${Paths.wallsdir}" --res 4k --json`];
        downloadSetProc.running = true;
    }

    function downloadToLibrary(slug) {
        Quickshell.execDetached(["mkdir", "-p", Paths.wallsdir]);
        downloadProc.command = ["sh", "-c", `cd "${scriptDir}" && python3 main.py --slug "${slug}" --output "${Paths.wallsdir}" --res 4k --json`];
        downloadProc.running = true;
    }

    readonly property Process fetchProc: Process {
        onRunningChanged: {
            if (!running)
                jsonView.reload();
        }
    }

    readonly property FileView jsonView: FileView {
        path: root._tmpJson
        watchChanges: false
        onLoaded: {
            try {
                const text = this.text();
                if (!text || text.trim() === "") {
                    root.wallpapers = [];
                    root.totalResults = 0;
                    root.lastPage = 1;
                    root.loading = false;
                    return;
                }
                const data = JSON.parse(text);
                root._allResults = data.map(function(w) {
                    let res = "1920x1080";
                    if (w.url_4k) res = "3840x2160";
                    else if (w.url_2k) res = "2560x1440";

                    return {
                        id: w.slug,
                        slug: w.slug,
                        path: w.url_4k || w.url_2k || w.url_1080p,
                        thumbs: {
                            small: w.url_thumb,
                            medium: w.url_thumb,
                            large: w.url_thumb
                        },
                        resolution: res,
                        url_4k: w.url_4k || "",
                        url_2k: w.url_2k || "",
                        url_1080p: w.url_1080p || ""
                    };
                });
                root.totalResults = data.length;
                root._applyPage();
            } catch (e) {
                console.warn("UHD parse error:", e);
                root.wallpapers = [];
                root.totalResults = 0;
            }
            root.loading = false;
        }
        onLoadFailed: {
            root.wallpapers = [];
            root.totalResults = 0;
            root.lastPage = 1;
            root.loading = false;
        }
    }

    readonly property Process downloadProc: Process {
        stdout: SplitParser {
            onRead: {}
        }
    }

    readonly property Process downloadSetProc: Process {
        stdout: SplitParser {
            onRead: {}
        }
    }
}
