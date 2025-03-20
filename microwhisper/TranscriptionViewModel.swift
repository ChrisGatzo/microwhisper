//
//  TranscriptionViewModel.swift
//  microwhisper
//
//  Created by Chris Gatzonis on 2/10/25.
//

import SwiftUI
import Combine

class TranscriptionViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0
    @Published var showTranscript: Bool = false
    
    // Audio source properties
    @Published var selectedAudioSource: AudioRecorderManager.AudioSource = .microphone
    @Published var isBlackholeAvailable: Bool = false
    @Published var isMicrophoneAvailable: Bool = true
    
    weak var appDelegate: AppDelegate?
    
    func toggleRecording() {
        appDelegate?.toggleRecording()
    }
    
    func appendTranscript(_ text: String) {
        if transcript.isEmpty {
            transcript = text
        } else {
            transcript += "\n\(text)"
        }
        showTranscript = !transcript.isEmpty
    }
    
    func clearTranscriptIfNeeded() {
        // Clear transcript when starting a new recording session
        transcript = ""
        showTranscript = false
    }
    
    func copyTranscriptToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
    }
}
