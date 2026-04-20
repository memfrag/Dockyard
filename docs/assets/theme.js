// Runs synchronously in <head> before the body paints, so the user's chosen
// theme is already applied by the time any content renders. Avoids a flash of
// light content on "dark" selection.
//
// CSP allows this because it's an external same-origin script (not inline).
(function () {
    var pref = null;
    try { pref = localStorage.getItem("dockyard.theme"); } catch (e) {}
    if (pref !== "dark" && pref !== "light") pref = "system";

    var systemDark = window.matchMedia &&
                     window.matchMedia("(prefers-color-scheme: dark)").matches;
    var dark = pref === "dark" || (pref === "system" && systemDark);

    if (dark) document.documentElement.classList.add("dark");
})();
