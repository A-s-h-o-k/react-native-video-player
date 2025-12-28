import React from 'react';
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
  return (
    <SafeAreaView style={styles.container} >
      <View style={{flex:1, height: '100%', width: '100%'}}>
        {playVideo ? (
          <View style={{ width: '100%', height: '100%' }}>
            <View style={{ width: '100%', height: '100%', backgroundColor:'green' }}>
              <WebView
                sourceURL="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
                style={styles.webview}
                onScriptLoaded={() => {
                  console.log('Page Loaded ===>>>>>.');
                }}
              />
            </View>
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
              onPress={() => setPlayVideo(true)}
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
    backgroundColor:'tan'
  },
  webview: {
    // flex:1,
    width: '100%',
    height: '100%',
    display: 'flex',
    // justifyContent: 'flex-end',
    // alignItems: 'flex-end',
    // backgroundColor: 'red',
  },
  button: {
    color: 'green',
    margin: 10,
    backgroundColor: 'blue',
  },
});

export default App;
