//
//  TranscriptionViewModel.swift
//  microwhisper
//
//  Created by Chris Gatzonis on 2/10/25.
//

import Foundation

class TranscriptionViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var audioLevel: Float = 0.0  // Normalized value: 0.0...1.0
    @Published var isRecording: Bool = false
    
    func appendTranscript(_ text: String) {
        transcript += text
    }
}

