pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.utils

QtObject {
    id: root

    property string apiKey: ""
    property var wallpapers: []
    property int currentPage: 1
    property int lastPage: 1
    property int totalResults: 0
    property string seed: ""
    property bool loading: false

    property string query: ""
    property string categories: "111"
    property string purity: "100"
    property string sorting: "date_added"
    property string atleast: ""
    property string colors: ""
    property string ratios: ""
    property string tags: ""
    property int topRange: 0

    readonly property string statePath: `${Paths.state}/wallhaven.json`

    Component.onCompleted: loadState()

    function search(q, cat, pur, sort, atleast_, colors_, ratios_, tags_, page) {
        query = q ?? "";
        categories = cat ?? "111";
        purity = pur ?? "100";
        sorting = sort ?? "date_added";
        atleast = atleast_ ?? "";
        colors = colors_ ?? "";
        ratios = ratios_ ?? "";
        tags = tags_ ?? "";
        currentPage = page || 1;
        wallpapers = [];
        saveState();
        _fetch();
    }

    function goToPage(page) {
        if (loading) return;
        if (page < 1 || page > lastPage) return;
        currentPage = page;
        _fetch();
    }

    function resetAndSearch(q, cat, pur, sort, atleast_, colors_, ratios_, tags_) {
        search(q, cat, pur, sort, atleast_, colors_, ratios_, tags_, 1);
    }

    function _fetch() {
        loading = true;

        const params = [];
        let qParam = "";
        if (query) qParam += query;
        if (tags) qParam += (qParam ? "+" : "") + tags;
        if (qParam) params.push("q=" + encodeURIComponent(qParam));

        if (categories !== "111") params.push("categories=" + categories);
        if (purity !== "100") params.push("purity=" + purity);
        if (sorting !== "date_added") params.push("sorting=" + sorting);
        if (atleast) params.push("atleast=" + atleast);
        if (colors) params.push("colors=" + colors);
        if (ratios) params.push("ratios=" + ratios);
        params.push("per_page=20");
        params.push("page=" + currentPage);
        if (seed && sorting === "random") params.push("seed=" + seed);
        if (apiKey) params.push("apikey=" + apiKey);

        const url = "https://wallhaven.cc/api/v1/search?" + params.join("&");
        Requests.get(url, function (text) {
            try {
                const resp = JSON.parse(text);
                wallpapers = resp.data || [];
                lastPage = resp.meta?.last_page ?? 1;
                totalResults = resp.meta?.total ?? 0;
                if (resp.meta?.seed) seed = resp.meta.seed;
            } catch (e) {
                console.warn("Wallhaven parse error:", e);
            }
            loading = false;
        }, function (err) {
            console.warn("Wallhaven API error:", err);
            loading = false;
        });
    }

    function downloadToLibrary(id, path) {
        Quickshell.execDetached(["mkdir", "-p", Paths.wallsdir]);
        const filename = path.split("/").pop();
        const targetPath = Paths.wallsdir + "/" + filename;
        downloadProc.command = ["curl", "-sL", "-o", targetPath, path];
        downloadProc.running = true;
    }

    function downloadAndSet(id, path) {
        Quickshell.execDetached(["mkdir", "-p", Paths.wallsdir]);
        const filename = path.split("/").pop();
        const targetPath = Paths.wallsdir + "/" + filename;
        downloadSetProc.command = ["sh", "-c", `curl -sL -o "${targetPath}" "${path}" && caelestia wallpaper -f "${targetPath}"`];
        downloadSetProc.running = true;
    }

    function saveState() {
        const state = JSON.stringify({
            apiKey: apiKey,
            query: query,
            categories: categories,
            purity: purity,
            sorting: sorting,
            atleast: atleast,
            colors: colors,
            ratios: ratios,
            tags: tags
        });
        saveProc.command = ["sh", "-c", `mkdir -p ${Paths.state} && cat > ${statePath} << 'WHEOF'\n${state}\nWHEOF`];
        saveProc.running = true;
    }

    function loadState() {
        stateView.reload();
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

    readonly property Process saveProc: Process {
        stdout: SplitParser {
            onRead: {}
        }
    }

    readonly property FileView stateView: FileView {
        path: root.statePath
        watchChanges: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (s.apiKey) root.apiKey = s.apiKey;
                if (s.query) root.query = s.query;
                if (s.categories) root.categories = s.categories;
                if (s.purity) root.purity = s.purity;
                if (s.sorting) root.sorting = s.sorting;
                if (s.atleast) root.atleast = s.atleast;
                if (s.colors) root.colors = s.colors;
                if (s.ratios) root.ratios = s.ratios;
                if (s.tags) root.tags = s.tags;
            } catch (e) {}
        }
        onLoadFailed: {}
    }
}
