import React from 'react';
import {
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { VideoPlayer } from './src';
import { SafeAreaView } from 'react-native-safe-area-context';

function App(): React.JSX.Element {
  const [playVideo, setPlayVideo] = React.useState(false);

  return (
    <SafeAreaView style={styles.container} edges={["top", "bottom"]}>
      <View style={{ flex: 1, height: '100%', width: '100%' }}>
        {playVideo ? (
          <View style={styles.videoContainer}>
            {/* Unified High-Performance Video Player */}
            <VideoPlayer
              videoUrl="https://lorem.video/720p"
              title="Big Buck Bunny (720p)"
              style={styles.webview}
              play={true}
              onScriptLoaded={() => console.log('Video Loaded')}
            />

            <TouchableOpacity
              onPress={() => setPlayVideo(false)}
              style={styles.button}
            >
              <Text style={styles.buttonText}>Stop Video</Text>
            </TouchableOpacity>
          </View>

        ) : (
          <View style={{ flex: 1, justifyContent: 'center' }}>
            <TouchableOpacity
              onPress={() => {
                setPlayVideo(true);
              }}
              style={styles.button}
            >
              <Text style={styles.buttonText}>Play Video</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    alignContent: 'center',
    width: '100%',
  },
  videoContainer: {
    flex: 1,
    width: '100%',
    backgroundColor: 'black', // Good practice to have a background for the video container
  },
  webview: {
    height: 300,
    width: '100%',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  controlsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 24,
  },
  button: {
    position: 'absolute', // Position the button over the video
    bottom: 50,
    alignSelf: 'center',
    backgroundColor: 'rgba(0, 122, 255, 0.8)',
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 25,
    margin: 10,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default App;
