# iOS Stem Player

A full-stack application that splits music tracks into individual stems (vocals, drums, bass, other) and provides an intuitive interface for real-time mixing and playback control.

## Features

- YouTube URL processing to extract audio
- Automatic stem separation using Demucs
- Real-time mixing interface with individual stem control
- Background processing with status updates and notifications
- Persistent storage of processed songs
- Synchronized playback of multiple audio streams
- High-quality MP3 compression for efficient storage
- Intuitive touch-based slider controls for stem mixing
- Visual feedback with LED indicators for muted tracks

## Technical Stack

### Backend (Python/Flask)
- Flask server with CORS support
- yt-dlp for YouTube audio extraction
- Demucs for stem separation
- Background task processing
- RESTful API endpoints
- File management system
- Status tracking and cleanup routines

### iOS Frontend (Swift/UIKit)
- Custom UI components with animations
- AVFoundation for audio playback
- Background processing management
- Persistent storage handling
- Touch gesture recognition
- Real-time audio mixing
- State management and synchronization

## Getting Started

1. Set up the Python backend:
   ```bash
   pip install flask yt-dlp demucs pydub flask-cors
   ```

2. Run the Flask server:
   ```bash
   python app.py
   ```

3. Open the iOS project in Xcode and update the `baseURL` in `MenuViewController.swift` to match your server's address.

4. Build and run the iOS application.

## License


This project uses the MIT license.
