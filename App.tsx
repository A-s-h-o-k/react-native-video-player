import React, { useState } from 'react';
import {
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { VideoPlayer, PlayerConfig } from './src';

const customRedTheme: PlayerConfig = {
  theme: {
    accentColor: '#E50914',
    trackColor: 'rgba(255, 255, 255, 0.25)',
    bufferColor: 'rgba(229, 9, 20, 0.35)',
  },
  behavior: {
    skipInterval: 10,
    autoHideTimeout: 3000,
    showRewindButton: true,
    showForwardButton: true,
    showPlayPauseButton: true,
    showFullscreenButton: true,
  },
};

function App(): React.JSX.Element {
  const [autoAdjust, setAutoAdjust] = useState(false);
  const [isPlaying, setIsPlaying] = useState(true);
  const [isMounted, setIsMounted] = useState(true);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [themeMode, setThemeMode] = useState<'default' | 'bundledJson' | 'customRed'>('default');

  const cycleTheme = () => {
    setThemeMode((prev) => {
      if (prev === 'default') return 'bundledJson';
      if (prev === 'bundledJson') return 'customRed';
      return 'default';
    });
  };

  return (
    <View style={styles.safeArea}>
      <StatusBar barStyle="light-content" backgroundColor="#000000" />
      <View style={styles.container}>
        <View style={styles.videoWrapper}>
          {isMounted && (
            <VideoPlayer
              videoUrl="https://lorem.video/720p"
              title="Big Buck Bunny (v1.0.0)"
              style={styles.player}
              play={isPlaying}
              showFullscreenButton={true}
              autoAdjustSafeArea={true}
              readFromJson={themeMode === 'bundledJson'}
              config={themeMode === 'customRed' ? customRedTheme : undefined}
              onFullscreenChange={(e) => {
                setIsFullscreen(e.nativeEvent.isFullscreen);
              }}
              onScriptLoaded={() => {
                console.log('[VideoPlayer] Video metadata parsed & ready');
              }}
              onError={(e) => {
                console.error('[VideoPlayer] Playback error:', e.nativeEvent.result);
              }}
            />
          )}
        </View>

        <View style={styles.controlPanel}>
          <Text style={styles.panelTitle}>Video Player v1.0.0 Demo</Text>
          <Text style={styles.statusText}>
            Status: {isMounted ? (isPlaying ? 'Playing' : 'Paused') : 'Stopped'} | Fullscreen: {isFullscreen ? 'Yes' : 'No'}
          </Text>
          <Text style={styles.themeInfoText}>
            Theme: {themeMode === 'default' ? 'Standard Props' : themeMode === 'bundledJson' ? 'Bundled default-player-config.json' : 'Custom Red JSON (Netflix style, 10s skip)'}
          </Text>

          <View style={styles.buttonGrid}>
            <TouchableOpacity
              onPress={() => setAutoAdjust((prev) => !prev)}
              style={styles.button}
              activeOpacity={0.8}
            >
              <Text style={styles.buttonText}>
                Safe Area: {autoAdjust ? 'ON' : 'OFF'}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => setIsPlaying((prev) => !prev)}
              style={[styles.button, styles.actionButton]}
              activeOpacity={0.8}
            >
              <Text style={styles.buttonText}>
                {isPlaying ? 'Pause' : 'Play'}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={cycleTheme}
              style={[styles.button, styles.themeButton]}
              activeOpacity={0.8}
            >
              <Text style={styles.buttonText}>
                Cycle Theme
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => setIsMounted((prev) => !prev)}
              style={[styles.button, isMounted ? styles.dangerButton : styles.successButton]}
              activeOpacity={0.8}
            >
              <Text style={styles.buttonText}>
                {isMounted ? 'Unmount' : 'Mount'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#000000',
  },
  container: {
    flex: 1,
    backgroundColor: '#121212',
  },
  videoWrapper: {
    width: '100%',
    height: 300,
    backgroundColor: '#000000',
  },
  player: {
    width: '100%',
    height: '100%',
  },
  controlPanel: {
    flex: 1,
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  panelTitle: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 8,
  },
  statusText: {
    color: '#AAAAAA',
    fontSize: 14,
    marginBottom: 8,
  },
  themeInfoText: {
    color: '#38BDF8',
    fontSize: 13,
    fontWeight: '500',
    marginBottom: 20,
    textAlign: 'center',
  },
  buttonGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 12,
  },
  button: {
    backgroundColor: '#2563EB',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    minWidth: 100,
    alignItems: 'center',
  },
  themeButton: {
    backgroundColor: '#8B5CF6',
  },
  actionButton: {
    backgroundColor: '#4B5563',
  },
  dangerButton: {
    backgroundColor: '#DC2626',
  },
  successButton: {
    backgroundColor: '#16A34A',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
});

export default App;
