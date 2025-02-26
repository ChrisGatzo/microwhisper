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
                
                Spacer(minLength: 20)
                
                // Main content
                VStack(spacing: 20) {
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
                        .frame(height: 160) // Fixed height for the orb container
                        
                        Text("Recording started...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                    
                    // Transcript area with fixed positioning
                    if viewModel.showTranscript {
                        VStack(alignment: .trailing) {
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
                            .background(Color(NSColor.textBackgroundColor).opacity(0.2))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                        .frame(height: viewModel.isRecording ? 200 : 400)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                    
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
                }
                .padding(.bottom, 40)
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
