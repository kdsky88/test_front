import React from 'react';
import { SafeAreaView, StyleSheet, Text } from 'react-native';

export default function App() {
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>TODO Front</Text>
      <Text style={styles.body}>Ready for TODO command UI.</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#ffffff'
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: '#111827'
  },
  body: {
    marginTop: 8,
    fontSize: 16,
    color: '#4b5563'
  }
});
