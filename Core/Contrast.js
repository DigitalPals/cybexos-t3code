// Colour contrast helpers, trimmed from Cybex OS's Common/SettingsHelpers.js
// (MIT). Pure JS so Node tests can load it.

function hexIn(value, fallback) {
    return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback;
}

function channelHex(value) {
    return Math.round(Math.min(1, Math.max(0, value)) * 255)
        .toString(16).padStart(2, "0");
}

function rgbIn(value, fallback) {
    var valid = hexIn(value, fallback || "#000000").toLowerCase();
    return [1, 3, 5].map(function(offset) {
        return parseInt(valid.slice(offset, offset + 2), 16) / 255;
    });
}

function relativeLuminance(value) {
    var linear = rgbIn(value).map(function(channel) {
        return channel <= 0.04045 ? channel / 12.92
            : Math.pow((channel + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

function contrastRatio(a, b) {
    var first = relativeLuminance(a);
    var second = relativeLuminance(b);
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

function mixHex(from, to, amount) {
    var start = rgbIn(from);
    var end = rgbIn(to);
    var t = Math.min(1, Math.max(0, amount));
    return "#" + start.map(function(channel, index) {
        return channelHex(channel + (end[index] - channel) * t);
    }).join("");
}

function foregroundFor(background) {
    return contrastRatio("#ffffff", background) >= contrastRatio("#000000", background)
        ? "#ffffff" : "#000000";
}

// The least foreground mixed over a background that reaches the contrast.
function contrastTone(background, foreground, target) {
    if (contrastRatio(foreground, background) < target)
        return foreground;
    var low = 0;
    var high = 1;
    for (var i = 0; i < 16; i++) {
        var mid = (low + high) / 2;
        if (contrastRatio(mixHex(background, foreground, mid), background) >= target)
            high = mid;
        else
            low = mid;
    }
    return mixHex(background, foreground, high);
}

// Keep a semantic colour when it already reads; otherwise pull it toward the
// background's foreground until it does.
function ensureContrast(value, background, target) {
    var source = hexIn(value, foregroundFor(background)).toLowerCase();
    if (contrastRatio(source, background) >= target)
        return source;
    var foreground = foregroundFor(background);
    var low = 0;
    var high = 1;
    for (var i = 0; i < 16; i++) {
        var mid = (low + high) / 2;
        if (contrastRatio(mixHex(source, foreground, mid), background) >= target)
            high = mid;
        else
            low = mid;
    }
    return mixHex(source, foreground, high);
}

function paletteTone(background, source, target) {
    return contrastRatio(source, background) < target
        ? ensureContrast(source, background, target)
        : contrastTone(background, source, target);
}

// The menubar's foreground ladder for a bar colour.
function barPalette(background) {
    var bg = hexIn(background, "#161424").toLowerCase();
    var foreground = foregroundFor(bg);
    var iconBase = foreground === "#ffffff" ? "#c2c6d1" : "#3a3850";
    return {
        background: bg,
        foreground: foreground,
        textHi: foreground,
        textMid: contrastTone(bg, foreground, 7.0),
        textLow: contrastTone(bg, foreground, 5.5),
        textDim: contrastTone(bg, foreground, 4.8),
        textFaint: contrastTone(bg, foreground, 4.5),
        icon: ensureContrast(iconBase, bg, 10.5)
    };
}

// A copy ladder from the theme's own foreground over a panel reference.
function textPalette(background, foreground) {
    var bg = hexIn(background, "#201e1b").toLowerCase();
    var hi = ensureContrast(hexIn(foreground, foregroundFor(bg)), bg, 7.0);
    return {
        textHi: hi,
        textMid: paletteTone(bg, hi, 7.0),
        textLow: paletteTone(bg, hi, 5.5),
        textDim: paletteTone(bg, hi, 4.8),
        textFaint: paletteTone(bg, hi, 4.5),
        icon: paletteTone(bg, hi, 6.0)
    };
}

var exported = {
    hexIn: hexIn,
    relativeLuminance: relativeLuminance,
    contrastRatio: contrastRatio,
    mixHex: mixHex,
    foregroundFor: foregroundFor,
    contrastTone: contrastTone,
    ensureContrast: ensureContrast,
    barPalette: barPalette,
    textPalette: textPalette
};

if (typeof module !== "undefined" && module.exports)
    module.exports = exported;
