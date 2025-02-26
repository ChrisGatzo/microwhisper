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
        // Optionally clear transcript when starting a new recording session
        // Uncomment if you want to clear previous transcripts on new recording
        // transcript = ""
    }
    
    func copyTranscriptToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
    }
}
