#!/usr/bin/env node

/**
 * scripts/build-theme.js
 * 
 * Ahead-Of-Time (AOT) Build-Time Theme & Asset Compiler for Enterprise React Native Video Player.
 * Reads `player-theme.json`, validates entries, auto-copies custom asset images into native
 * Android and iOS resource bundles, and generates type-safe native constants.
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
const CONFIG_FILE = path.join(ROOT_DIR, 'player-theme.json');
const ANDROID_GEN_DIR = path.join(ROOT_DIR, 'android/app/src/main/java/com/player/ui/generated');
const ANDROID_DRAWABLE_DIR = path.join(ROOT_DIR, 'android/app/src/main/res/drawable');
const IOS_GEN_DIR = path.join(ROOT_DIR, 'ios/VideoPlayer/Generated');
const IOS_RES_DIR = path.join(ROOT_DIR, 'ios/VideoPlayer/Resources');

const DEFAULT_THEME = {
  theme: {
    accentColor: '#FFFFFF',
    trackColor: 'rgba(255, 255, 255, 0.2)',
    bufferColor: 'rgba(255, 255, 255, 0.4)',
  },
  icons: {
    play: 'play.fill',
    pause: 'pause.fill',
    replay: 'gobackward',
    rewind: 'gobackward.15',
    forward: 'goforward.15',
    fullscreenEnter: 'viewfinder',
    fullscreenExit: 'arrow.down.right.and.arrow.up.left',
    sliderThumb: '',
  },
  behavior: {
    skipInterval: 15,
    autoHideTimeout: 5000,
    showRewindButton: true,
    showForwardButton: true,
    showPlayPauseButton: true,
    showFullscreenButton: false,
    controls: true,
  },
  strict: true,
};

function ensureDirSync(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function isValidHexColor(hex) {
  if (typeof hex !== 'string') return false;
  if (hex.startsWith('rgba') || hex.startsWith('rgb')) return true;
  return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex);
}

function sanitizeResourceName(name) {
  return name.toLowerCase().replace(/[^a-z0-9_]/g, '_');
}

function run() {
  console.log('⚡ [VideoPlayer AOT] Starting Ahead-Of-Time Theme & Asset Compilation...');

  let config = { ...DEFAULT_THEME };
  let isCustom = false;

  if (fs.existsSync(CONFIG_FILE)) {
    try {
      const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
      const parsed = JSON.parse(raw);
      isCustom = true;
      config = {
        strict: parsed.strict !== undefined ? parsed.strict : DEFAULT_THEME.strict,
        theme: { ...DEFAULT_THEME.theme, ...(parsed.theme || {}) },
        icons: { ...DEFAULT_THEME.icons, ...(parsed.icons || {}) },
        behavior: { ...DEFAULT_THEME.behavior, ...(parsed.behavior || {}) },
      };
      console.log(`📁 [VideoPlayer AOT] Loaded custom configuration from: ${CONFIG_FILE}`);
    } catch (err) {
      console.error(`❌ [VideoPlayer AOT Error] Failed to parse player-theme.json: ${err.message}`);
      process.exit(1);
    }
  } else {
    console.log('ℹ️  [VideoPlayer AOT] No custom player-theme.json found. Compiling default native theme...');
  }

  // --- 1. Validation ---
  const { theme, icons, behavior, strict } = config;

  // Validate accentColor
  if (!isValidHexColor(theme.accentColor)) {
    const msg = `Invalid color format for "theme.accentColor": "${theme.accentColor}". Expected hex (e.g. #E50914) or rgb/rgba string.`;
    if (strict) {
      console.error(`❌ [VideoPlayer AOT Error] ${msg}`);
      process.exit(1);
    } else {
      console.warn(`⚠️  [VideoPlayer AOT Warning] ${msg} Falling back to ${DEFAULT_THEME.theme.accentColor}`);
      theme.accentColor = DEFAULT_THEME.theme.accentColor;
    }
  }

  // Validate skipInterval
  if (typeof behavior.skipInterval !== 'number' || behavior.skipInterval < 1) {
    const msg = `Invalid skipInterval: "${behavior.skipInterval}". Must be a positive integer >= 1.`;
    if (strict) {
      console.error(`❌ [VideoPlayer AOT Error] ${msg}`);
      process.exit(1);
    } else {
      console.warn(`⚠️  [VideoPlayer AOT Warning] ${msg} Falling back to 15.`);
      behavior.skipInterval = 15;
    }
  }

  // Validate autoHideTimeout
  if (typeof behavior.autoHideTimeout !== 'number' || behavior.autoHideTimeout < 0) {
    behavior.autoHideTimeout = 5000;
  }

  // --- 2. Asset Bundling (Images) ---
  ensureDirSync(ANDROID_DRAWABLE_DIR);
  ensureDirSync(IOS_RES_DIR);
  ensureDirSync(ANDROID_GEN_DIR);
  ensureDirSync(IOS_GEN_DIR);

  const resolvedIcons = {};

  for (const [key, iconVal] of Object.entries(icons)) {
    if (!iconVal || typeof iconVal !== 'string') {
      resolvedIcons[key] = '';
      continue;
    }

    const isFilePath = iconVal.startsWith('./') || iconVal.startsWith('/') || /\.(png|jpg|jpeg|webp|svg)$/i.test(iconVal);

    if (isFilePath) {
      const resolvedAssetPath = path.isAbsolute(iconVal) ? iconVal : path.resolve(ROOT_DIR, iconVal);

      if (!fs.existsSync(resolvedAssetPath)) {
        const msg = `Asset file not found for "icons.${key}": "${iconVal}"\n   Resolved path: "${resolvedAssetPath}"`;
        if (strict) {
          console.error(`❌ [VideoPlayer AOT Error] ${msg}`);
          console.error(`👉 Ensure the image exists at that path or remove "icons.${key}" to use system defaults.`);
          process.exit(1);
        } else {
          console.warn(`⚠️  [VideoPlayer AOT Warning] ${msg}. Falling back to default system icon.`);
          resolvedIcons[key] = DEFAULT_THEME.icons[key] || '';
          continue;
        }
      }

      // Valid file on disk -> Bundle it natively!
      const ext = path.extname(resolvedAssetPath).toLowerCase();
      const safeKey = sanitizeResourceName(key);
      const nativeAssetName = `player_aot_${safeKey}`;

      // Copy to Android res/drawable
      const androidDest = path.join(ANDROID_DRAWABLE_DIR, `${nativeAssetName}${ext}`);
      fs.copyFileSync(resolvedAssetPath, androidDest);

      // Copy to iOS Resources
      const iosDest = path.join(IOS_RES_DIR, `${nativeAssetName}${ext}`);
      fs.copyFileSync(resolvedAssetPath, iosDest);

      console.log(`📦 [VideoPlayer AOT] Bundled icon "${key}" -> Native asset: ${nativeAssetName}${ext}`);
      resolvedIcons[key] = nativeAssetName;
    } else {
      // System symbol (SF Symbol / Android system resource name)
      resolvedIcons[key] = iconVal;
    }
  }

  // --- 3. Generate Android Native Class ---
  const androidKotlinContent = `package com.player.ui.generated

/**
 * AUTO-GENERATED BY scripts/build-theme.js
 * DO NOT EDIT DIRECTLY. Modifications will be overwritten during build.
 * Compiled at: ${new Date().toISOString()}
 */
object PlayerThemeGenerated {
    const val IS_CUSTOM_THEME: Boolean = ${isCustom}
    const val ACCENT_COLOR: String = "${theme.accentColor}"
    const val TRACK_COLOR: String = "${theme.trackColor}"
    const val BUFFER_COLOR: String = "${theme.bufferColor}"
    const val SKIP_INTERVAL: Int = ${behavior.skipInterval}
    const val AUTO_HIDE_TIMEOUT: Int = ${behavior.autoHideTimeout}
    const val SHOW_REWIND_BUTTON: Boolean = ${Boolean(behavior.showRewindButton)}
    const val SHOW_FORWARD_BUTTON: Boolean = ${Boolean(behavior.showForwardButton)}
    const val SHOW_PLAY_PAUSE_BUTTON: Boolean = ${Boolean(behavior.showPlayPauseButton)}
    const val SHOW_FULLSCREEN_BUTTON: Boolean = ${Boolean(behavior.showFullscreenButton)}

    // Icon & Notch Asset References
    const val ICON_PLAY: String = "${resolvedIcons.play || ''}"
    const val ICON_PAUSE: String = "${resolvedIcons.pause || ''}"
    const val ICON_REPLAY: String = "${resolvedIcons.replay || ''}"
    const val ICON_REWIND: String = "${resolvedIcons.rewind || ''}"
    const val ICON_FORWARD: String = "${resolvedIcons.forward || ''}"
    const val ICON_FULLSCREEN_ENTER: String = "${resolvedIcons.fullscreenEnter || ''}"
    const val ICON_FULLSCREEN_EXIT: String = "${resolvedIcons.fullscreenExit || ''}"
    const val ICON_SLIDER_THUMB: String = "${resolvedIcons.sliderThumb || ''}"
    const val ICON_BACK: String = "${resolvedIcons.back || ''}"
    const val ICON_CAPTIONS: String = "${resolvedIcons.captions || ''}"
    const val ICON_SETTINGS: String = "${resolvedIcons.settings || ''}"
}
`;

  const androidFile = path.join(ANDROID_GEN_DIR, 'PlayerThemeGenerated.kt');
  fs.writeFileSync(androidFile, androidKotlinContent, 'utf8');
  console.log(`✅ [VideoPlayer AOT] Generated Android theme: ${path.relative(ROOT_DIR, androidFile)}`);

  // --- 4. Generate iOS Native Header ---
  const iosHeaderContent = `/**
 * AUTO-GENERATED BY scripts/build-theme.js
 * DO NOT EDIT DIRECTLY. Modifications will be overwritten during build.
 * Compiled at: ${new Date().toISOString()}
 */

#ifndef PlayerThemeGenerated_h
#define PlayerThemeGenerated_h

#import <Foundation/Foundation.h>

#define THEME_GEN_IS_CUSTOM ${isCustom ? 'YES' : 'NO'}
#define THEME_GEN_ACCENT_COLOR @"${theme.accentColor}"
#define THEME_GEN_TRACK_COLOR @"${theme.trackColor}"
#define THEME_GEN_BUFFER_COLOR @"${theme.bufferColor}"
#define THEME_GEN_SKIP_INTERVAL ${behavior.skipInterval}
#define THEME_GEN_AUTO_HIDE_TIMEOUT ${behavior.autoHideTimeout}
#define THEME_GEN_SHOW_REWIND_BUTTON ${behavior.showRewindButton ? 'YES' : 'NO'}
#define THEME_GEN_SHOW_FORWARD_BUTTON ${behavior.showForwardButton ? 'YES' : 'NO'}
#define THEME_GEN_SHOW_PLAY_PAUSE_BUTTON ${behavior.showPlayPauseButton ? 'YES' : 'NO'}
#define THEME_GEN_SHOW_FULLSCREEN_BUTTON ${behavior.showFullscreenButton ? 'YES' : 'NO'}

// Icon & Notch Asset References
#define THEME_GEN_ICON_PLAY @"${resolvedIcons.play || ''}"
#define THEME_GEN_ICON_PAUSE @"${resolvedIcons.pause || ''}"
#define THEME_GEN_ICON_REPLAY @"${resolvedIcons.replay || ''}"
#define THEME_GEN_ICON_REWIND @"${resolvedIcons.rewind || ''}"
#define THEME_GEN_ICON_FORWARD @"${resolvedIcons.forward || ''}"
#define THEME_GEN_ICON_FULLSCREEN_ENTER @"${resolvedIcons.fullscreenEnter || ''}"
#define THEME_GEN_ICON_FULLSCREEN_EXIT @"${resolvedIcons.fullscreenExit || ''}"
#define THEME_GEN_ICON_SLIDER_THUMB @"${resolvedIcons.sliderThumb || ''}"
#define THEME_GEN_ICON_BACK @"${resolvedIcons.back || ''}"
#define THEME_GEN_ICON_CAPTIONS @"${resolvedIcons.captions || ''}"
#define THEME_GEN_ICON_SETTINGS @"${resolvedIcons.settings || ''}"

#endif /* PlayerThemeGenerated_h */
`;

  const iosFile = path.join(IOS_GEN_DIR, 'PlayerThemeGenerated.h');
  fs.writeFileSync(iosFile, iosHeaderContent, 'utf8');
  const iosRootFile = path.join(ROOT_DIR, 'ios/VideoPlayer/PlayerThemeGenerated.h');
  fs.writeFileSync(iosRootFile, iosHeaderContent, 'utf8');
  console.log(`✅ [VideoPlayer AOT] Generated iOS theme: ${path.relative(ROOT_DIR, iosFile)}`);
  console.log('🎉 [VideoPlayer AOT] Build-Time Compilation Completed Successfully.\n');
}

run();
