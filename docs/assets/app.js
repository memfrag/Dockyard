// Dockyard for web — entry point.
// Loads manifest.json + editorial.json once, routes hash changes, and renders
// the matching view. All strings from the data sources are inserted via
// textContent or via DOMPurify-sanitized markdown — never innerHTML.

import { rank } from "./search.js";

const MANIFEST_URL = "https://raw.githubusercontent.com/memfrag/DockyardManifest/main/manifest.json";
const EDITORIAL_URL = "https://raw.githubusercontent.com/memfrag/DockyardManifest/main/editorial.json";

const state = {
    manifest: null,    // { schemaVersion, generatedAt, apps: [CatalogEntry] }
    editorial: null    // { schemaVersion, generatedAt, today: {...} | null }
};

const contentEl = document.getElementById("content");
const searchInput = document.getElementById("search");

// ------------------------------------------------------------
// Sidebar icons (inlined SVG so CSP can stay strict)
// ------------------------------------------------------------

const ICONS = {
    today:         `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 9h18M8 3v4M16 3v4"/></svg>`,
    discover:      `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.39 6.95L22 9.27l-5.5 5.27L17.82 22 12 18.27 6.18 22l1.32-7.46L2 9.27l7.61-.32z"/></svg>`,
    design:        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></svg>`,
    development:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 7l6 5-6 5M10 7L4 12l6 5"/></svg>`,
    entertainment: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polygon points="6 4 20 12 6 20 6 4" fill="currentColor" stroke="none"/></svg>`,
    finance:       `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>`,
    productivity:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 19l7-14 7 14M5 15h14"/></svg>`,
    download:      `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v12m0 0l-4-4m4 4l4-4M4 20h16"/></svg>`,
    "appearance-system": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 1 0 16z" fill="currentColor" stroke="none"/></svg>`,
    "appearance-light":  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="4" fill="currentColor" stroke="none"/><path d="M12 2v3M12 19v3M4.22 4.22l2.12 2.12M17.66 17.66l2.12 2.12M2 12h3M19 12h3M4.22 19.78l2.12-2.12M17.66 6.34l2.12-2.12"/></svg>`,
    "appearance-dark":   `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.8 13.8A7 7 0 0 1 10.2 6.2 7 7 0 1 0 17.8 13.8z"/></svg>`
};

function paintSidebarIcons() {
    document.querySelectorAll("[data-symbol]").forEach(paintSymbol);
}

function paintSymbol(element) {
    const key = element.dataset.symbol;
    const svg = ICONS[key];
    if (svg) element.innerHTML = svg; // trusted: from our own constant
}

// ------------------------------------------------------------
// Appearance (light / dark / system)
// ------------------------------------------------------------

const THEME_ORDER = ["system", "light", "dark"];
const THEME_STORAGE_KEY = "dockyard.theme";
const darkQuery = window.matchMedia("(prefers-color-scheme: dark)");

function getThemePref() {
    try {
        const stored = localStorage.getItem(THEME_STORAGE_KEY);
        if (stored === "light" || stored === "dark") return stored;
    } catch {}
    return "system";
}

function setThemePref(pref) {
    try {
        if (pref === "system") {
            localStorage.removeItem(THEME_STORAGE_KEY);
        } else {
            localStorage.setItem(THEME_STORAGE_KEY, pref);
        }
    } catch {}
    applyTheme(pref);
    updateThemeButton(pref);
}

function applyTheme(pref) {
    const dark = pref === "dark" || (pref === "system" && darkQuery.matches);
    document.documentElement.classList.toggle("dark", dark);
}

function updateThemeButton(pref) {
    const btn = document.getElementById("theme-toggle");
    if (!btn) return;
    const icon = btn.querySelector(".theme-toggle-icon");
    icon.dataset.symbol = `appearance-${pref}`;
    paintSymbol(icon);
    const label = pref.charAt(0).toUpperCase() + pref.slice(1);
    btn.title = `Appearance: ${label} (click to cycle)`;
    btn.setAttribute("aria-label", `Appearance: ${label}. Click to cycle.`);
}

function cycleTheme() {
    const current = getThemePref();
    const next = THEME_ORDER[(THEME_ORDER.indexOf(current) + 1) % THEME_ORDER.length];
    setThemePref(next);
}

function bindThemeToggle() {
    const btn = document.getElementById("theme-toggle");
    if (!btn) return;
    btn.addEventListener("click", cycleTheme);
    updateThemeButton(getThemePref());
    // React to OS-level changes when pref is "system".
    darkQuery.addEventListener("change", () => {
        if (getThemePref() === "system") applyTheme("system");
    });
}

// ------------------------------------------------------------
// Data loading
// ------------------------------------------------------------

async function loadJSON(url, cacheKey) {
    try {
        const cached = sessionStorage.getItem(cacheKey);
        if (cached) return JSON.parse(cached);
    } catch {}
    const res = await fetch(url, { cache: "no-cache" });
    if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`);
    const text = await res.text();
    try { sessionStorage.setItem(cacheKey, text); } catch {}
    return JSON.parse(text);
}

async function bootstrap() {
    paintSidebarIcons();
    bindThemeToggle();
    bindSearchField();

    try {
        const [manifest, editorial] = await Promise.all([
            loadJSON(MANIFEST_URL, "dockyard.manifest"),
            loadJSON(EDITORIAL_URL, "dockyard.editorial").catch(() => null)
        ]);
        state.manifest = manifest;
        state.editorial = editorial;
    } catch (err) {
        showError(`Couldn't load the catalog: ${err.message}`);
        return;
    }

    window.addEventListener("hashchange", renderRoute);
    renderRoute();
}

function showError(message) {
    contentEl.replaceChildren();
    const banner = document.createElement("div");
    banner.className = "error-banner";
    banner.textContent = message;
    contentEl.appendChild(banner);
}

// ------------------------------------------------------------
// Router
// ------------------------------------------------------------

function parseHash() {
    const hash = window.location.hash.replace(/^#\/?/, "");
    const parts = hash.split("/").filter(Boolean);
    if (parts.length === 0) return { route: "today" };
    const [head, ...rest] = parts;
    switch (head) {
        case "today":    return { route: "today" };
        case "discover": return { route: "discover" };
        case "category": return { route: "category", category: decodeURIComponent(rest[0] ?? "") };
        case "app":      return { route: "app", id: decodeURIComponent(rest[0] ?? "") };
        default:         return { route: "today" };
    }
}

function renderRoute() {
    const query = (searchInput.value || "").trim();
    if (query) {
        renderSearch(query);
        updateActiveNav(null);
        return;
    }
    const parsed = parseHash();
    switch (parsed.route) {
        case "today":
            renderToday();
            updateActiveNav("#/today");
            break;
        case "discover":
            renderCatalog({
                title: "Discover",
                pretitle: "Catalog",
                description: `${state.manifest.apps.length} app${state.manifest.apps.length === 1 ? "" : "s"} available`,
                entries: state.manifest.apps
            });
            updateActiveNav("#/discover");
            break;
        case "category": {
            const cat = parsed.category;
            const filtered = state.manifest.apps.filter(e => e.category === cat);
            renderCatalog({
                title: cat,
                pretitle: "Category",
                description: filtered.length === 0
                    ? "No apps yet"
                    : `${filtered.length} app${filtered.length === 1 ? "" : "s"} in this category.`,
                entries: filtered,
                emptyTitle: `No ${cat.toLowerCase()} apps yet`,
                emptyMessage: `Apps in this category will appear here.`
            });
            updateActiveNav(`#/category/${encodeURIComponent(cat)}`);
            break;
        }
        case "app": {
            const entry = state.manifest.apps.find(e => e.id === parsed.id);
            if (!entry) {
                renderCatalog({
                    title: "Not found",
                    pretitle: "App",
                    description: `No catalog entry with id "${parsed.id}".`,
                    entries: []
                });
            } else {
                renderDetails(entry);
            }
            updateActiveNav(null);
            break;
        }
    }
    window.scrollTo(0, 0);
}

function updateActiveNav(hash) {
    document.querySelectorAll(".nav-link").forEach(el => {
        el.classList.toggle("active", el.getAttribute("href") === hash);
    });
}

// ------------------------------------------------------------
// Search field
// ------------------------------------------------------------

function bindSearchField() {
    searchInput.addEventListener("input", () => {
        renderRoute();
    });
}

function renderSearch(query) {
    const results = rank(state.manifest.apps, query);
    renderCatalog({
        title: "Search",
        pretitle: "Search",
        description: `${results.length} result${results.length === 1 ? "" : "s"} for "${query}"`,
        entries: results,
        emptyTitle: "No matches",
        emptyMessage: "Try a different query."
    });
}

// ------------------------------------------------------------
// Views
// ------------------------------------------------------------

function renderCatalog({ title, pretitle, description, entries, emptyTitle, emptyMessage }) {
    contentEl.replaceChildren();
    const pane = el("div", { class: "pane" });
    pane.appendChild(paneHeader({ title, pretitle, description }));

    if (!entries || entries.length === 0) {
        pane.appendChild(emptyState({
            title: emptyTitle || "Nothing here yet",
            message: emptyMessage || ""
        }));
    } else {
        pane.appendChild(cardGrid(entries));
    }

    contentEl.appendChild(pane);
}

function renderToday() {
    contentEl.replaceChildren();
    const pane = el("div", { class: "pane" });
    const today = state.editorial?.today;
    const title = today?.title || "Today";
    const date = new Intl.DateTimeFormat(undefined, {
        weekday: "long", day: "numeric", month: "long"
    }).format(new Date());

    pane.appendChild(paneHeader({ title, pretitle: `Today · ${date}` }));

    if (!today) {
        pane.appendChild(emptyState({
            title: "Today is taking a break",
            message: "New editorial content will appear here soon."
        }));
        contentEl.appendChild(pane);
        return;
    }

    const heroEntry = today.editorsPick ? lookup(today.editorsPick.appID) : null;
    const highlights = (today.highlights || [])
        .map(h => ({ highlight: h, entry: lookup(h.appID) }))
        .filter(pair => pair.entry);

    if (heroEntry || highlights.length > 0) {
        const heroRow = el("div", { class: "today-hero-row" });
        if (today.editorsPick && heroEntry) {
            heroRow.appendChild(editorsPick(today.editorsPick, heroEntry));
        }
        if (highlights.length > 0) {
            const col = el("div", { class: "highlights-column" });
            for (const { highlight, entry } of highlights) {
                col.appendChild(highlightCard(highlight, entry));
            }
            heroRow.appendChild(col);
        }
        pane.appendChild(heroRow);
    }

    for (const section of (today.sections || [])) {
        const sectionEl = el("div", { class: "pane-section" });
        const header = el("div", { class: "pane-section-header" });
        header.appendChild(textEl("h2", "pane-section-title", section.title));
        if (section.subtitle) {
            header.appendChild(textEl("p", "pane-section-subtitle", section.subtitle));
        }
        sectionEl.appendChild(header);
        const sectionEntries = (section.appIDs || [])
            .map(lookup)
            .filter(Boolean);
        if (sectionEntries.length > 0) {
            sectionEl.appendChild(cardGrid(sectionEntries));
        }
        pane.appendChild(sectionEl);
    }

    contentEl.appendChild(pane);
}

function renderDetails(entry) {
    contentEl.replaceChildren();
    const pane = el("div", { class: "pane" });

    // Header row
    const row = el("div", { class: "details-header-row" });
    row.appendChild(appIcon(entry, "details-icon"));
    const body = el("div", { class: "details-header-body" });

    const categoryRow = el("div", { class: "card-category-row" });
    categoryRow.appendChild(textEl("span", "details-category", entry.category || ""));
    if (entry.channel && entry.channel !== "Release") {
        categoryRow.appendChild(textEl("span", "channel-badge", entry.channel));
    }
    body.appendChild(categoryRow);
    body.appendChild(textEl("h1", "details-title", entry.displayName || ""));
    body.appendChild(textEl("p", "details-summary", entry.summary || ""));

    const actions = el("div", { class: "details-actions" });
    actions.appendChild(downloadLink(entry, "Download", "capsule-btn accent"));
    if (entry.github) {
        const gh = entry.github;
        const href = `https://github.com/${encodeURIComponent(gh.owner)}/${encodeURIComponent(gh.repo)}`;
        actions.appendChild(externalLink(href, "GitHub", "capsule-btn"));
    }
    body.appendChild(actions);
    row.appendChild(body);
    pane.appendChild(row);

    pane.appendChild(el("div", { class: "details-divider" }));

    // Properties
    const props = el("div", { class: "details-properties" });
    props.appendChild(propertyBlock("Version", entry.version));
    props.appendChild(propertyBlock("Size", formatBytes(entry.dmgSize)));
    if (entry.requiredVersion) {
        props.appendChild(propertyBlock("Requires", `macOS ${entry.requiredVersion}`));
    }
    if (entry.developer) {
        props.appendChild(propertyBlock("Developer", entry.developer));
    }
    pane.appendChild(props);

    // Screenshots
    if (entry.screenshotURLs && entry.screenshotURLs.length > 0) {
        pane.appendChild(el("div", { class: "details-divider" }));
        const section = el("div", { class: "details-section" });
        section.appendChild(textEl("h2", "details-section-title", "Screenshots"));
        const strip = el("div", { class: "screenshots-row" });
        for (const url of entry.screenshotURLs) {
            if (!isHttpURL(url)) continue;
            const img = document.createElement("img");
            img.className = "screenshot";
            img.src = url;
            img.alt = `${entry.displayName} screenshot`;
            img.loading = "lazy";
            strip.appendChild(img);
        }
        section.appendChild(strip);
        pane.appendChild(section);
    }

    // What's New
    if (entry.releaseNotes && entry.releaseNotes.trim()) {
        pane.appendChild(el("div", { class: "details-divider" }));
        const section = el("div", { class: "details-section" });
        section.appendChild(textEl("h2", "details-section-title", `What's New in ${entry.version}`));
        section.appendChild(markdownBlock(entry.releaseNotes));
        pane.appendChild(section);
    }

    // About (fetched asynchronously)
    if (entry.aboutURL) {
        const section = el("div", { class: "details-section", id: "about-section" });
        section.appendChild(el("div", { class: "details-divider" }));
        section.appendChild(textEl("h2", "details-section-title", "About"));
        const placeholder = el("p", { class: "empty-state" });
        placeholder.textContent = "Loading…";
        section.appendChild(placeholder);
        pane.appendChild(section);

        fetchText(entry.aboutURL)
            .then(text => {
                if (!text || !text.trim()) {
                    section.remove();
                    return;
                }
                section.replaceChild(markdownBlock(text), placeholder);
            })
            .catch(() => section.remove());
    }

    contentEl.appendChild(pane);
}

// ------------------------------------------------------------
// Component builders
// ------------------------------------------------------------

function paneHeader({ title, pretitle, description }) {
    const el0 = el("header", { class: "pane-header" });
    if (pretitle) el0.appendChild(textEl("span", "pane-pretitle", pretitle));
    if (title) el0.appendChild(textEl("h1", "pane-title", title));
    if (description) el0.appendChild(textEl("p", "pane-description", description));
    return el0;
}

function emptyState({ title, message }) {
    const wrapper = el("div", { class: "empty-state" });
    wrapper.appendChild(textEl("h4", null, title));
    if (message) wrapper.appendChild(textEl("p", null, message));
    return wrapper;
}

function cardGrid(entries) {
    const grid = el("div", { class: "card-grid" });
    for (const entry of entries) {
        grid.appendChild(appCard(entry));
    }
    return grid;
}

function appCard(entry) {
    const card = el("div", { class: "app-card", role: "button", tabindex: "0" });
    card.addEventListener("click", (e) => {
        if (e.target.closest(".capsule-btn")) return; // don't navigate on download click
        navigateToApp(entry.id);
    });
    card.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            navigateToApp(entry.id);
        }
    });

    const row = el("div", { class: "app-card-row" });
    row.appendChild(appIcon(entry, "app-icon"));

    const body = el("div", { class: "app-card-body" });
    const catRow = el("div", { class: "card-category-row" });
    catRow.appendChild(textNode(entry.category || ""));
    if (entry.channel && entry.channel !== "Release") {
        catRow.appendChild(textEl("span", "channel-badge", entry.channel));
    }
    body.appendChild(catRow);
    body.appendChild(textEl("div", "app-card-title", entry.displayName || ""));
    body.appendChild(textEl("div", "app-card-description", entry.summary || ""));

    row.appendChild(body);
    row.appendChild(downloadLink(entry, "Download", "capsule-btn"));
    card.appendChild(row);
    return card;
}

function highlightCard(highlight, entry) {
    const card = el("div", { class: "highlight-card", role: "button", tabindex: "0" });
    card.addEventListener("click", () => navigateToApp(entry.id));
    card.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            navigateToApp(entry.id);
        }
    });

    card.appendChild(appIcon(entry, "app-icon"));
    const body = el("div", { class: "highlight-card-body" });
    body.appendChild(textEl("div", "card-category-row", (highlight.category || "").toUpperCase()));
    body.appendChild(textEl("div", "highlight-card-title", entry.displayName || ""));
    body.appendChild(textEl("div", "highlight-card-description", highlight.description || ""));
    card.appendChild(body);
    return card;
}

function editorsPick(pick, entry) {
    const card = el("div", { class: "editors-pick", role: "button", tabindex: "0" });
    const gradient = parseGradient(pick.gradient);
    if (gradient) {
        card.style.background = `linear-gradient(135deg, ${gradient[0]} 0%, ${gradient[1]} 100%)`;
    }
    card.addEventListener("click", (e) => {
        if (e.target.closest(".capsule-btn")) return;
        navigateToApp(entry.id);
    });
    card.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            navigateToApp(entry.id);
        }
    });

    card.appendChild(textEl("div", "editors-pick-category", (pick.category || "Editor's Pick").toUpperCase()));
    card.appendChild(textEl("div", "editors-pick-headline", pick.headline || ""));
    card.appendChild(textEl("div", "editors-pick-description", pick.description || ""));

    const footer = el("div", { class: "editors-pick-footer" });
    const icon = el("img", { class: "editors-pick-icon", src: safeImageURL(entry.iconURL), alt: "" });
    footer.appendChild(icon);

    const info = el("div", { class: "editors-pick-app" });
    info.appendChild(textEl("div", "editors-pick-name", entry.displayName || ""));
    info.appendChild(textEl("div", "editors-pick-author", entry.developer ? `by ${entry.developer}` : `Version ${entry.version || ""}`));
    footer.appendChild(info);

    footer.appendChild(downloadLink(entry, "Download", "capsule-btn editors-pick-btn"));
    card.appendChild(footer);
    return card;
}

function propertyBlock(label, value) {
    const block = el("div");
    block.appendChild(textEl("div", "details-property-label", label));
    block.appendChild(textEl("div", "details-property-value", value || ""));
    return block;
}

function appIcon(entry, className) {
    const img = document.createElement("img");
    img.className = className;
    img.src = safeImageURL(entry.iconURL);
    img.alt = `${entry.displayName || "App"} icon`;
    img.loading = "lazy";
    return img;
}

function downloadLink(entry, label, classNames) {
    const a = document.createElement("a");
    a.className = classNames;
    const url = safeDownloadURL(entry.dmgURL);
    a.href = url || "#";
    if (url) {
        a.setAttribute("download", "");
    } else {
        a.setAttribute("aria-disabled", "true");
    }
    a.textContent = label;
    a.addEventListener("click", (e) => e.stopPropagation());
    return a;
}

function externalLink(href, label, classNames) {
    const a = document.createElement("a");
    a.className = classNames;
    a.href = href;
    a.textContent = label;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    a.addEventListener("click", (e) => e.stopPropagation());
    return a;
}

function markdownBlock(src) {
    const wrapper = el("div", { class: "markdown" });
    const html = (window.marked && window.DOMPurify)
        ? window.DOMPurify.sanitize(window.marked.parse(src, { breaks: true }), {
              USE_PROFILES: { html: true }
          })
        : escapeForInnerHTML(src);
    wrapper.innerHTML = html; // safe: sanitized
    // Force safe external link behavior
    wrapper.querySelectorAll("a[href]").forEach(a => {
        try {
            const url = new URL(a.href, window.location.href);
            if (["https:", "mailto:"].includes(url.protocol)) {
                a.target = "_blank";
                a.rel = "noopener noreferrer";
            } else {
                a.removeAttribute("href");
            }
        } catch {
            a.removeAttribute("href");
        }
    });
    return wrapper;
}

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

function el(tag, attrs = {}) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
        if (v == null) continue;
        node.setAttribute(k, v);
    }
    return node;
}

function textEl(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = text == null ? "" : String(text);
    return node;
}

function textNode(str) {
    return document.createTextNode(str == null ? "" : String(str));
}

function lookup(id) {
    if (!id || !state.manifest) return null;
    return state.manifest.apps.find(e => e.id === id) || null;
}

function navigateToApp(id) {
    window.location.hash = `#/app/${encodeURIComponent(id)}`;
}

function formatBytes(bytes) {
    if (typeof bytes !== "number" || bytes <= 0) return "";
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let i = 0;
    let value = bytes;
    while (value >= 1024 && i < units.length - 1) {
        value /= 1024;
        i++;
    }
    return `${value.toFixed(value >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
}

function parseGradient(arr) {
    if (!Array.isArray(arr) || arr.length < 2) return null;
    const hexRe = /^#?[0-9a-fA-F]{6}$/;
    if (!hexRe.test(arr[0]) || !hexRe.test(arr[1])) return null;
    const norm = s => s.startsWith("#") ? s : `#${s}`;
    return [norm(arr[0]), norm(arr[1])];
}

function isHttpURL(value) {
    try {
        const u = new URL(value);
        return u.protocol === "http:" || u.protocol === "https:";
    } catch {
        return false;
    }
}

function safeImageURL(value) {
    if (typeof value !== "string") return "";
    return isHttpURL(value) ? value : "";
}

function safeDownloadURL(value) {
    return safeImageURL(value); // same rules: must be http(s)
}

async function fetchText(url) {
    if (!isHttpURL(url)) return null;
    const res = await fetch(url);
    if (!res.ok) return null;
    return await res.text();
}

function escapeForInnerHTML(text) {
    const tmp = document.createElement("div");
    tmp.textContent = text;
    return `<pre>${tmp.innerHTML}</pre>`;
}

// ------------------------------------------------------------
// Go
// ------------------------------------------------------------

bootstrap();
