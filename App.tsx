import React, { useEffect } from 'react';
import {
  Alert,
  Button,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import WebView from './specs/VideoPlayerNativeComponent';
import { SafeAreaView } from 'react-native-safe-area-context';

function App(): React.JSX.Element {
  const [playVideo, setPlayVideo] = React.useState(false);
  const [videoPlay, setVideoPlay] = React.useState(false);
  const videoRef = React.useRef(null);

  // useEffect(()  => {
  //   setTimeout(() => {
  //       setVideoPlay(false)
  //   }, 5000)
  // }, []);

  return (
    <SafeAreaView style={styles.container}>
      <View style={{ flex: 1, height: '100%', width: '100%' }}>
        {playVideo ? (
          // This container holds both the video and the button overlay
          <View style={styles.videoContainer}>
            <WebView
            ref={videoRef}
              videoUrl="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
              style={styles.webview}
              onScriptLoaded={() => console.log('Page Loaded ===>>>>>.')}
              play={true}
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
    flex: 1, // This makes the video view fill the videoContainer
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
