"use strict";

// ---------------------------------------------------------------------------
// Bridge to AutoHotkey (WebViewToo host objects).
//
// AHK registers callbacks with AddCallbackToScript("Name", Func); they appear
// here as `ahk.Name(args...)` returning Promises. AHK pushes updates back with
// PostWebMessageAsJson(...), received via the 'message' event.
// ---------------------------------------------------------------------------

const isHost = !!(window.chrome && window.chrome.webview && typeof ahk !== "undefined");

const mockState = {
    general: { startTarget: 40, increment: 5, updateInterval: 100, lockOnToggle: false },
    settings: { onlyFocused: true, logging: true, gameProcess: "RobloxPlayerBeta.exe" },
    hotkeys: {
        Region: "F5", Toggle: "F6", IncrementUp: "F7", IncrementDown: "F8",
        Debug: "F9", Cancel: "~s", Settings: "F10", ToggleHud: "F11",
    },
    controller: {
        PwmPeriod: 300, Kp: 0.08, Ki: 0.02, Kd: 0.05, FullThrottleGap: 10,
        BrakeSoftGap: 4, BrakeHardGap: 8, BrakeAccelThreshold: 2.0,
        BrakeReleaseGap: 1.5, BrakeLookahead: 0.6, MinBrakeHold: 500, MinBrakeSpeed: 8,
    },
    hud: { X: 20, Y: 20, Width: 324, Opacity: 225, Visible: true, ClickThrough: false },
    ocr: { Language: "en-us", Scale: 3, Grayscale: false, InvertColors: false, Monochrome: 0 },
    region: { x: 0, y: 0, w: 0, h: 0, set: false },
    debug: { version: "v0.0.0", os: "Windows", ahk: "v2.0", webview2: "-", game: "not found", region: "not set", logging: "on", dataDir: "" },
};

async function call(name, ...args) {
    if (isHost && typeof ahk[name] === "function") return await ahk[name](...args);
    throw new Error("No AHK handler for " + name);
}

const Bridge = {
    isHost,
    async getState() {
        if (isHost) return JSON.parse(await call("GetState"));
        return JSON.parse(JSON.stringify(mockState));
    },
    async save(state) {
        if (isHost) return await call("Save", JSON.stringify(state));
        Object.assign(mockState, state);
        return "Saved (preview).";
    },
    async resetDefaults() {
        if (isHost) return JSON.parse(await call("ResetDefaults"));
        return JSON.parse(JSON.stringify(mockState));
    },
    async openDataFolder() {
        if (isHost) return await call("OpenDataFolder");
        return "Preview mode.";
    },
    async openLogs() {
        if (isHost) return await call("OpenLogs");
        return "Preview mode.";
    },
    async selectRegion() {
        if (isHost) { await call("SelectRegion"); return JSON.parse(await call("GetState")); }
        return mockState;
    },
    async testRead() {
        if (isHost) return await call("TestRead");
        return "Preview mode.";
    },
};

// ---------------------------------------------------------------------------
// Hotkeys: stored as AHK syntax (^!+R), shown as "Ctrl + Alt + Shift + R".
// ---------------------------------------------------------------------------

function ahkToFriendly(hk) {
    if (!hk) return "Not set";
    let s = hk;
    const parts = [];
    while (s.length && "^!+#".includes(s[0])) {
        if (s[0] === "^") parts.push("Ctrl");
        else if (s[0] === "!") parts.push("Alt");
        else if (s[0] === "+") parts.push("Shift");
        else if (s[0] === "#") parts.push("Win");
        s = s.slice(1);
    }
    let key = s;
    const aliases = { PgUp: "PageUp", PgDn: "PageDown", Esc: "Escape", BS: "Backspace", Del: "Delete", Ins: "Insert" };
    if (aliases[key]) key = aliases[key];
    if (key.length === 1) key = key.toUpperCase();
    parts.push(key);
    return parts.join(" + ");
}

function eventToAhk(e) {
    if (["Control", "Alt", "Shift", "Meta"].includes(e.key)) return "";
    if (e.key === "Escape") return "";

    let main;
    if (/^F\d{1,2}$/.test(e.key)) main = e.key;
    else if (e.key === " ") main = "Space";
    else if (e.key === "ArrowUp") main = "Up";
    else if (e.key === "ArrowDown") main = "Down";
    else if (e.key === "ArrowLeft") main = "Left";
    else if (e.key === "ArrowRight") main = "Right";
    else if (e.key === "PageUp") main = "PgUp";
    else if (e.key === "PageDown") main = "PgDn";
    else if (e.key === "Backspace") main = "BS";
    else if (e.key === "Delete") main = "Del";
    else if (e.key === "Insert") main = "Ins";
    else if (e.key.length === 1) main = e.key.toUpperCase();
    else main = e.key;

    let prefix = "";
    if (e.ctrlKey) prefix += "^";
    if (e.altKey) prefix += "!";
    if (e.shiftKey) prefix += "+";
    if (e.metaKey) prefix += "#";
    return prefix + main;
}

function setHotkeyField(field, ahkCombo) {
    field.dataset.raw = ahkCombo || "";
    field.value = ahkToFriendly(ahkCombo);
}

function initHotkeyFields(root) {
    (root || document).querySelectorAll("[data-hotkey]").forEach((field) => {
        field.addEventListener("click", () => {
            document.querySelectorAll("[data-hotkey].is-capturing").forEach((f) => {
                f.classList.remove("is-capturing", "recording");
                setHotkeyField(f, f.dataset.raw);
            });
            field.classList.add("is-capturing", "recording");
            field.value = "Press a key...";
        });
    });

    document.addEventListener("keydown", (e) => {
        const field = document.querySelector("[data-hotkey].is-capturing");
        if (!field) return;
        e.preventDefault();
        const combo = eventToAhk(e);
        if (!combo) {
            if (e.key === "Escape") {
                field.classList.remove("is-capturing", "recording");
                setHotkeyField(field, "");
            }
            return;
        }
        field.classList.remove("is-capturing", "recording");
        setHotkeyField(field, combo);
    });
}

// ---------------------------------------------------------------------------
// Field definitions for the numeric grids
// ---------------------------------------------------------------------------

const HOTKEY_FIELDS = [
    ["Region", "Select region"],
    ["Toggle", "Cruise on/off"],
    ["IncrementUp", "Target + increment"],
    ["IncrementDown", "Target − increment"],
    ["Debug", "Debug toggle"],
    ["Cancel", "Cancel (brake)"],
    ["Settings", "Open settings"],
    ["ToggleHud", "Toggle HUD"],
];

const PID_FIELDS = [
    ["Kp", "Kp", 0.01],
    ["Ki", "Ki", 0.005],
    ["Kd", "Kd", 0.01],
];

const GAP_FIELDS = [
    ["PwmPeriod", "PWM period (ms)", 10],
    ["FullThrottleGap", "Full-throttle gap (mph)", 1],
];

const BRAKE_FIELDS = [
    ["BrakeSoftGap", "Soft gap (mph)", 1],
    ["BrakeHardGap", "Hard gap (mph)", 1],
    ["BrakeAccelThreshold", "Accel threshold (mph/s)", 0.1],
    ["BrakeReleaseGap", "Release gap (mph)", 0.1],
    ["BrakeLookahead", "Lookahead (s)", 0.1],
    ["MinBrakeHold", "Min hold (ms)", 50],
    ["MinBrakeSpeed", "Min speed (mph)", 1],
];

const HUD_FIELDS = [
    ["X", "X", 1],
    ["Y", "Y", 1],
    ["Width", "Width", 1],
    ["Opacity", "Opacity (30-255)", 5],
];

const OCR_FIELDS = [
    ["Language", "Language (e.g. en-us)", null],
    ["Scale", "Scale", 1],
    ["Monochrome", "Monochrome threshold (0 = off)", 5],
];

function fieldInput(id, label, value, step) {
    const wrap = document.createElement("div");
    wrap.className = "field-item";
    const lab = document.createElement("label");
    lab.className = "field-label";
    lab.textContent = label;
    lab.htmlFor = id;
    const input = document.createElement("input");
    input.className = "field";
    input.id = id;
    if (step == null) input.type = "text";
    else { input.type = "number"; input.step = step; }
    input.value = value;
    wrap.append(lab, input);
    return wrap;
}

function renderHotkeys(hotkeys) {
    const grid = document.getElementById("hk-grid");
    grid.innerHTML = "";
    HOTKEY_FIELDS.forEach(([key, label]) => {
        const wrap = document.createElement("div");
        wrap.className = "field-item";
        const lab = document.createElement("label");
        lab.className = "field-label";
        lab.textContent = label;
        const input = document.createElement("input");
        input.className = "field field-hk";
        input.type = "text";
        input.readOnly = true;
        input.dataset.hotkey = "";
        input.dataset.name = key;
        setHotkeyField(input, hotkeys[key]);
        wrap.append(lab, input);
        grid.appendChild(wrap);
    });
    initHotkeyFields(grid);
}

function renderGrid(gridId, fields, source) {
    const grid = document.getElementById(gridId);
    grid.innerHTML = "";
    fields.forEach(([key, label, step]) => grid.appendChild(fieldInput(key, label, source[key], step)));
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

function initTabs() {
    const nav = document.getElementById("nav");
    nav.addEventListener("click", (e) => {
        const btn = e.target.closest(".nav-item");
        if (!btn) return;
        nav.querySelectorAll(".nav-item").forEach((b) => b.classList.toggle("is-active", b === btn));
        document.querySelectorAll(".page").forEach((p) => p.classList.toggle("is-active", p.dataset.page === btn.dataset.tab));
    });
}

// ---------------------------------------------------------------------------
// Render state
// ---------------------------------------------------------------------------

function render(state) {
    // General
    document.getElementById("startTarget").value = state.general.startTarget;
    document.getElementById("increment").value = state.general.increment;
    document.getElementById("updateInterval").value = state.general.updateInterval;
    document.getElementById("lockOnToggle").checked = !!state.general.lockOnToggle;

    // Settings
    document.getElementById("onlyFocused").checked = !!state.settings.onlyFocused;
    document.getElementById("logging").checked = !!state.settings.logging;
    document.getElementById("gameProcess").value = state.settings.gameProcess || "";

    // Hotkeys
    renderHotkeys(state.hotkeys || {});

    // Tuning
    renderGrid("pid-grid", PID_FIELDS, state.controller);
    renderGrid("gap-grid", GAP_FIELDS, state.controller);
    renderGrid("brake-grid", BRAKE_FIELDS, state.controller);

    // HUD
    document.getElementById("hudVisible").checked = !!state.hud.Visible;
    document.getElementById("hudClickThrough").checked = !!state.hud.ClickThrough;
    renderGrid("hud-grid", HUD_FIELDS, state.hud);

    // OCR
    document.getElementById("ocrGrayscale").checked = !!state.ocr.Grayscale;
    document.getElementById("ocrInvert").checked = !!state.ocr.InvertColors;
    renderGrid("ocr-grid", OCR_FIELDS, state.ocr);

    const r = state.region || {};
    document.getElementById("region-summary").textContent = r.set
        ? `Region: ${r.x}, ${r.y} — ${r.w} x ${r.h} px`
        : "No region set. Click Select region, then drag over your speedometer.";

    const dot = document.getElementById("engine-dot");
    const label = document.getElementById("engine-label");
    const ready = r.set;
    dot.className = "engine-dot " + (ready ? "ok" : "bad");
    label.textContent = ready ? "Ready" : "Region needed";

    renderAbout(state.debug || {});
}

function renderAbout(d) {
    const dl = document.getElementById("about-info");
    dl.innerHTML = "";
    const rows = [
        ["Version", d.version],
        ["Operating system", d.os],
        ["AutoHotkey", d.ahk],
        ["WebView2", d.webview2],
        ["Game", d.game],
        ["Region", d.region],
        ["Logging", d.logging],
        ["Data folder", d.dataDir],
    ];
    rows.forEach(([k, v]) => {
        const dt = document.createElement("dt");
        dt.textContent = k;
        const dd = document.createElement("dd");
        dd.textContent = v != null && v !== "" ? String(v) : "-";
        dl.append(dt, dd);
    });
    dl.dataset.raw = rows.map(([k, v]) => k + ": " + (v || "-")).join("\n");
}

// ---------------------------------------------------------------------------
// Collect
// ---------------------------------------------------------------------------

function num(id) {
    const el = document.getElementById(id);
    return el.value;
}

function collectGrid(gridId) {
    const out = {};
    document.getElementById(gridId).querySelectorAll("input.field").forEach((el) => {
        out[el.id] = el.value;
    });
    return out;
}

function collect() {
    const hotkeys = {};
    document.querySelectorAll("#hk-grid [data-hotkey]").forEach((el) => {
        hotkeys[el.dataset.name] = el.dataset.raw || "";
    });

    return {
        general: {
            startTarget: num("startTarget"),
            increment: num("increment"),
            updateInterval: num("updateInterval"),
            lockOnToggle: document.getElementById("lockOnToggle").checked,
        },
        settings: {
            onlyFocused: document.getElementById("onlyFocused").checked,
            logging: document.getElementById("logging").checked,
            gameProcess: num("gameProcess"),
        },
        hotkeys,
        controller: Object.assign({}, collectGrid("pid-grid"), collectGrid("gap-grid"), collectGrid("brake-grid")),
        hud: Object.assign(
            { Visible: document.getElementById("hudVisible").checked, ClickThrough: document.getElementById("hudClickThrough").checked },
            collectGrid("hud-grid")
        ),
        ocr: Object.assign(
            { Grayscale: document.getElementById("ocrGrayscale").checked, InvertColors: document.getElementById("ocrInvert").checked },
            collectGrid("ocr-grid")
        ),
    };
}

function setStatus(message, kind) {
    const el = document.getElementById("status");
    el.textContent = message;
    el.dataset.kind = kind || "";
}

function initTitleBar() {
    const gui = (typeof ahk !== "undefined" && ahk.gui) ? ahk.gui : null;
    if (!gui) return;
    document.getElementById("win-min").addEventListener("click", () => gui.Minimize());
    document.getElementById("win-close").addEventListener("click", () => {
        if (typeof ahk.CloseWindow === "function") ahk.CloseWindow();
        else gui.Hide();
    });
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function initActions() {
    document.getElementById("save").addEventListener("click", async () => {
        setStatus("Saving...");
        try {
            setStatus((await Bridge.save(collect())) || "Saved.", "ok");
        } catch (e) {
            setStatus("Save failed: " + e, "err");
        }
    });

    document.getElementById("open-folder").addEventListener("click", () => Bridge.openDataFolder());
    document.getElementById("open-logs").addEventListener("click", () => Bridge.openLogs());

    document.getElementById("select-region").addEventListener("click", async () => {
        setStatus("Select a region on screen...");
        try {
            render(await Bridge.selectRegion());
            setStatus("Region saved.", "ok");
        } catch (e) {
            setStatus("Region selection failed: " + e, "err");
        }
    });

    document.getElementById("test-read").addEventListener("click", async () => {
        setStatus("Reading...");
        try {
            await Bridge.testRead();
        } catch (e) {
            setStatus("Test failed: " + e, "err");
        }
    });

    document.getElementById("reset-tuning").addEventListener("click", async () => {
        if (!confirm("Reset ALL settings to their defaults?")) return;
        try {
            render(await Bridge.resetDefaults());
            setStatus("Defaults restored.", "ok");
        } catch (e) {
            setStatus("Reset failed: " + e, "err");
        }
    });

    document.getElementById("hud-snap-tl").addEventListener("click", () => {
        document.getElementById("X").value = 20;
        document.getElementById("Y").value = 20;
    });
    document.getElementById("hud-snap-tr").addEventListener("click", () => {
        const w = parseInt(document.getElementById("Width").value, 10) || 324;
        document.getElementById("X").value = Math.max(0, (window.screen.availWidth || 1920) - w - 20);
        document.getElementById("Y").value = 20;
    });

    document.getElementById("copy-debug").addEventListener("click", async () => {
        const raw = document.getElementById("about-info").dataset.raw || "";
        try {
            await navigator.clipboard.writeText(raw);
            setStatus("Debug info copied.", "ok");
        } catch {
            setStatus("Could not copy.", "err");
        }
    });
}

// ---------------------------------------------------------------------------
// Messages from AHK
// ---------------------------------------------------------------------------

if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener("message", (event) => {
        let msg = event.data;
        if (typeof msg === "string") {
            try { msg = JSON.parse(msg); }
            catch { setStatus(msg); return; }
        }
        if (msg && msg.type === "status") setStatus(msg.message, msg.kind);
        else if (msg && msg.type === "state") render(msg.state);
    });
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

async function boot() {
    initTabs();
    initTitleBar();
    initActions();
    try {
        render(await Bridge.getState());
        setStatus(isHost ? "Ready." : "Preview mode (no AHK host).");
    } catch (e) {
        setStatus("Could not load settings: " + e, "err");
    }
}

document.addEventListener("DOMContentLoaded", boot);
