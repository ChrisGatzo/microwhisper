# MicroWhisper

A macOS application that provides real-time audio transcription using OpenAI's Whisper model. The app sits in your menu bar and can be triggered with a global keyboard shortcut to start/stop recording.

## Features

- Real-time audio recording with visual feedback
- Global keyboard shortcut (⌥⇧R) to start/stop recording
- Visual audio level indicator while recording
- Instant transcription using Whisper's tiny.en model
- Selectable transcript text
- Clean, minimal SwiftUI interface

## Requirements

- macOS 15.2 or later
- Whisper CLI installed (`/usr/local/bin/whisper`)
- Microphone access permission

## Installation

1. Clone this repository
2. Open the project in Xcode
3. Install Whisper CLI if you haven't already:
   ```bash
   # Install Whisper CLI (if using Homebrew)
   brew install whisper
   ```
4. Build and run the project in Xcode

## Usage

1. Launch the application
2. Press ⌥⇧R (Option + Shift + R) to start recording
3. Speak into your microphone
4. Press ⌥⇧R again to stop recording and start transcription
5. The transcribed text will appear in the window
6. You can select and copy the transcribed text

## Technical Details

- Built with SwiftUI and AVFoundation
- Uses CGEventTap for global keyboard shortcut handling
- Implements real-time audio level monitoring
- Processes audio using Whisper's tiny.en model for fast transcription

## Privacy

The application requires microphone access to function. All processing is done locally using the Whisper model, and no audio data is sent to external servers.

## License

This project is available under the MIT License. See the LICENSE file for more details.