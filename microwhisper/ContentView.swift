import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @State private var hoveringCopy: Bool = false
    
    var body: some View {
        ZStack {
            // Visual effect background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom title bar
                HStack {
                    Spacer()
                    Text("microwhisper")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 30)
                .padding(.top, 10)
                
                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 20)
                        
                        // Recording visualization
                        if viewModel.isRecording {
                            ZStack {
                                // Pulse effect
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 140 + CGFloat(viewModel.audioLevel * 60),
                                           height: 140 + CGFloat(viewModel.audioLevel * 60))
                                    .opacity(0.8)
                                    .animation(.easeInOut(duration: 0.2), value: viewModel.audioLevel)
                                
                                // Second pulse layer
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.3)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 120 + CGFloat(viewModel.audioLevel * 40),
                                           height: 120 + CGFloat(viewModel.audioLevel * 40))
                                    .opacity(0.7)
                                
                                // Main orb
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(1.0 + CGFloat(viewModel.audioLevel * 0.3))
                                    .animation(.easeInOut(duration: 0.05), value: viewModel.audioLevel)
                                    .shadow(color: Color.purple.opacity(0.5), radius: 15, x: 0, y: 0)
                            }
                            .frame(maxHeight: 160) // Use maxHeight instead of fixed height
                            
                            Text("Recording started...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        }
                        
                        // Transcript area with flexible sizing
                        if viewModel.showTranscript {
                            VStack(alignment: .trailing, spacing: 8) {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        viewModel.copyTranscriptToPasteboard()
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 14))
                                            .foregroundColor(hoveringCopy ? .primary : .secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .onHover { hovering in
                                        hoveringCopy = hovering
                                    }
                                    .help("Copy transcript to clipboard")
                                }
                                .padding(.trailing, 10)
                                
                                ScrollView {
                                    Text(viewModel.transcript)
                                        .font(.system(size: 14))
                                        .padding()
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 100, maxHeight: .infinity)
                                .background(Color(NSColor.textBackgroundColor).opacity(0.2))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 30)
                            .frame(minHeight: 200, maxHeight: viewModel.isRecording ? 200 : .infinity)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                            .transition(.opacity)
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Audio source selector
                        if !viewModel.isRecording {
                            VStack(spacing: 10) {
                                Text("Audio Source")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 15) {
                                    // Microphone button
                                    Button(action: {
                                        viewModel.selectedAudioSource = .microphone
                                    }) {
                                        VStack(spacing: 5) {
                                            Image(systemName: "mic")
                                                .font(.system(size: 18))
                                                .foregroundColor(viewModel.selectedAudioSource == .microphone ? .blue : .secondary)
                                            
                                            Text("Microphone")
                                                .font(.system(size: 12))
                                                .foregroundColor(viewModel.selectedAudioSource == .microphone ? .blue : .secondary)
                                        }
                                        .frame(width: 100, height: 60)
                                        .background(viewModel.selectedAudioSource == .microphone ? 
                                                  Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(!viewModel.isMicrophoneAvailable)
                                    .opacity(viewModel.isMicrophoneAvailable ? 1.0 : 0.5)
                                    
                                    // System Audio button
                                    Button(action: {
                                        viewModel.selectedAudioSource = .systemAudio
                                    }) {
                                        VStack(spacing: 5) {
                                            Image(systemName: "speaker.wave.3")
                                                .font(.system(size: 18))
                                                .foregroundColor(viewModel.selectedAudioSource == .systemAudio ? .blue : .secondary)
                                            
                                            Text("System Audio")
                                                .font(.system(size: 12))
                                                .foregroundColor(viewModel.selectedAudioSource == .systemAudio ? .blue : .secondary)
                                        }
                                        .frame(width: 100, height: 60)
                                        .background(viewModel.selectedAudioSource == .systemAudio ? 
                                                  Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(!viewModel.isBlackholeAvailable)
                                    .opacity(viewModel.isBlackholeAvailable ? 1.0 : 0.5)
                                    .help(viewModel.isBlackholeAvailable ? "Record system audio using BlackHole" : "BlackHole not detected. Please install BlackHole to record system audio.")
                                }
                                
                                if !viewModel.isBlackholeAvailable {
                                    Text("BlackHole not detected")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 5)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        
                        // Recording controls
                        Button(action: {
                            viewModel.toggleRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                    .frame(width: 50, height: 50)
                                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                                
                                if viewModel.isRecording {
                                    // Stop button (square)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: 20, height: 20)
                                } else {
                                    // Record button (circle)
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 20, height: 20)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(viewModel.isRecording ? "Stop recording" : "Start recording")
                        .padding(.bottom, 20)
                        
                        // Show current audio source during recording
                        if viewModel.isRecording {
                            HStack(spacing: 5) {
                                Image(systemName: viewModel.selectedAudioSource == .microphone ? "mic" : "speaker.wave.3")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Text("Recording from \(viewModel.selectedAudioSource == .microphone ? "Microphone" : "System Audio")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// Helper for NSVisualEffectView to enable window transparency
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
