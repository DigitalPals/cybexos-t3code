pragma Singleton
import QtQuick
import Quickshell
import qs.Commons as Commons
import "Contrast.js" as Contrast

// The plugin's design tokens. The T3 Code widget was written against the
// Cybex OS shell's private Theme; a plugin may not import that, so this
// singleton derives the same token names from the public `qs.Commons`
// Color/Style API the host shares with every Omarchy plugin. At the shell's
// default settings the sizes match the built-in widget; colours follow the
// active theme's foreground, background and accent.
Singleton {
    id: root

    function opaque(value) {
        const c = Qt.color(value);
        const hex = channel => Math.round(Math.min(1, Math.max(0, channel)) * 255)
            .toString(16).padStart(2, "0");
        return "#" + hex(c.r) + hex(c.g) + hex(c.b);
    }

    function withAlpha(value, alpha) {
        const c = Qt.color(value);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    // ---- scale -------------------------------------------------------------
    // The shell scales its tokens from a 12px reference, as Commons.Style
    // does, so `scaled(v)` equals the built-in's at the same settings while
    // also following the plugin interface scale (Settings → Appearance).
    readonly property real contentScale: Commons.Style.effectiveSpacingScale
    readonly property real typeScale: Commons.Style.fontBaseSize / 12
    function scaled(value, scale) {
        return Math.round(value * (scale === undefined ? contentScale : scale));
    }

    readonly property string reducedMotionValue:
        (Quickshell.env("QS_REDUCED_MOTION") || "").trim().toLowerCase()
    readonly property bool reducedMotion: T3Host.reducedMotion
        || ["1", "true", "yes", "on"].includes(reducedMotionValue)

    // ---- palette -----------------------------------------------------------
    readonly property color background: Commons.Color.background
    readonly property bool dark: Contrast.relativeLuminance(opaque(background)) < 0.4
    readonly property color popBg: background
    readonly property color menuBg: Commons.Color.menu.background
    readonly property color surfaceMenu: menuBg
    // Outer panels share the menubar fill, including glass.
    readonly property color barSurface: Commons.Color.panelBackground
    readonly property color panelSurface: barSurface
    readonly property color lightInk: "#18162c"

    readonly property color copyReferenceBg: dark
        ? Contrast.mixHex(opaque(popBg), "#ffffff", 0.09)
        : Contrast.mixHex(opaque(popBg), opaque(lightInk), 0.13)
    readonly property var textLadder: Contrast.textPalette(opaque(copyReferenceBg),
        opaque(Commons.Color.foreground))
    readonly property color textHi: textLadder.textHi
    readonly property color textMid: textLadder.textMid
    readonly property color textLow: textLadder.textLow
    readonly property color textDim: textLadder.textDim
    readonly property color textFaint: textLadder.textFaint
    readonly property color icon: textLadder.icon
    readonly property color dotDim: dark
        ? Qt.rgba(245 / 255, 244 / 255, 251 / 255, 0.30)
        : Qt.rgba(28 / 255, 26 / 255, 46 / 255, 0.26)

    readonly property color stroke: dark ? Qt.rgba(1, 1, 1, 0.13)
        : withAlpha(lightInk, 0.13)
    readonly property color hairlineSoft: dark ? Qt.rgba(1, 1, 1, 0.05)
        : withAlpha(lightInk, 0.06)
    readonly property color chip: dark ? Qt.rgba(1, 1, 1, 0.08) : withAlpha(lightInk, 0.07)
    readonly property color chipHover: dark ? Qt.rgba(1, 1, 1, 0.16) : withAlpha(lightInk, 0.13)
    readonly property real stateHoverOpacity: 0.08
    readonly property real statePressedOpacity: 0.12
    readonly property color hoverFill: chip
    readonly property color hoverFillStrong: chipHover

    readonly property color accent: Commons.Color.accent
    readonly property color accentText: Contrast.ensureContrast(opaque(accent),
        opaque(copyReferenceBg), 4.5)
    readonly property color accentFg: Contrast.foregroundFor(opaque(accent)) === "#ffffff"
        ? "#ffffff" : "#1c1c12"
    readonly property color accentBg: withAlpha(accent, 0.24)
    readonly property color accentBgSoft: withAlpha(accent, 0.12)
    readonly property color accentGlow: withAlpha(accent, 0.50)

    readonly property color redText: Contrast.ensureContrast(
        opaque(Commons.Color.urgent), opaque(copyReferenceBg), 4.5)
    readonly property color redBgSoft: withAlpha(Commons.Color.urgent, 0.10)
    readonly property color redBorder: withAlpha(Commons.Color.urgent, 0.38)
    readonly property color amberSeed: dark ? "#ffc26e" : "#b5761e"
    readonly property color amber: Contrast.ensureContrast(opaque(amberSeed),
        opaque(copyReferenceBg), 4.5)
    readonly property color amberBgSoft: withAlpha(amberSeed, dark ? 0.09 : 0.08)
    readonly property color amberBorder: withAlpha(amberSeed, dark ? 0.38 : 0.35)
    readonly property color okSeed: dark ? "#63d68c" : "#1f9d57"
    readonly property color ok: Contrast.ensureContrast(opaque(okSeed),
        opaque(copyReferenceBg), 4.5)

    // ---- menubar -----------------------------------------------------------
    readonly property color barBg: opaque(barSurface)
    readonly property var barPalette: Contrast.barPalette(opaque(barBg))
    readonly property bool barLightForeground:
        Contrast.relativeLuminance(barPalette.foreground) > 0.5
    readonly property color barTextHi: T3Host.barForeground !== ""
        ? T3Host.barForeground : barPalette.textHi
    readonly property color barTextMid: barPalette.textMid
    readonly property color barTextLow: barPalette.textLow
    readonly property color barTextFaint: barPalette.textFaint
    readonly property color barIcon: barPalette.icon
    readonly property color barChipHover: barLightForeground
        ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color barAccent: Contrast.ensureContrast(opaque(accent),
        opaque(barBg), 4.5)
    readonly property color barAccentGlow: withAlpha(barAccent, 0.50)
    readonly property color barAmber: Contrast.ensureContrast(
        barLightForeground ? "#ffc26e" : "#b5761e", opaque(barBg), 4.5)
    readonly property int barHeight: T3Host.barSize > 0 ? T3Host.barSize : chipHeight + 8
    readonly property int barSpacing: 4

    // ---- borders -----------------------------------------------------------
    // The host's popup card draws the panel's border; inner surfaces need none.
    readonly property color surfaceBorderColor: "transparent"
    readonly property int surfaceBorderWidth: 0

    // ---- type --------------------------------------------------------------
    readonly property string fontMenu: Commons.Style.font.family
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontLabel: fontMono
    readonly property var typography: Commons.Style.typography
    readonly property real proseLineHeight: /mono/i.test(fontMenu) ? 1.55
        : /grotesk/i.test(fontMenu) ? 1.5 : 1.45
    readonly property int weightRegular: 400
    readonly property int weightMedium: 500
    readonly property int weightSemibold: 600
    readonly property int weightBold: 700
    readonly property var tabularNumberFeatures: ({ "tnum": 1 })

    readonly property int iconTiny: scaled(11, typeScale)
    readonly property int iconSmall: scaled(13, typeScale)
    readonly property int iconMedium: scaled(16, typeScale)
    readonly property int iconLarge: scaled(20, typeScale)
    readonly property int iconHero: scaled(27, typeScale)

    // ---- metrics -----------------------------------------------------------
    readonly property int chipHeight: scaled(28)
    readonly property int chipInnerHeight: scaled(24)
    readonly property int chipRadius: 7
    readonly property int popWidth: scaled(408)
    readonly property int t3MinWidth: 360
    readonly property int t3MaxWidth: 520
    readonly property int controlHeight: scaled(46)
    readonly property int inlineActionHeight: scaled(32)
    readonly property int pickerRowHeight: scaled(40)
    readonly property int panelRadius: Commons.Style.cornerRadius
    readonly property int panelPadding: scaled(14)
    readonly property int sectionHeaderHeight: scaled(22)
    readonly property int listRowHeight: scaled(34)
    readonly property int panelHeaderHeight: scaled(52)
    readonly property int panelFooterHeight: scaled(30)
    readonly property int panelSectionSpacing: scaled(16)
    readonly property int settingsContentSpacing: scaled(8)
    readonly property int controlSpacing: scaled(8)
    readonly property int iconTextSpacing: scaled(6)

    // Focus rings show for keyboard use only, as in the shell.
    readonly property int focusRingWidth: 2
    function focusWidth(focused) {
        return focused && T3Host.keyboardModality ? focusRingWidth : 0;
    }

    // ---- motion ------------------------------------------------------------
    readonly property var springCurve: [0.32, 1.15, 0.3, 1.0, 1.0, 1.0]
    readonly property int chipFadeDuration: reducedMotion ? 0 : 160
    readonly property int pressDuration: reducedMotion ? 0 : 180
    readonly property int expandDuration: reducedMotion ? 0 : 280
    readonly property int surfaceDuration: reducedMotion ? 0 : 300
}
