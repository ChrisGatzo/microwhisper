import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    
    var body: some View {
        VStack {
            if viewModel.isRecording {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(1.0 + CGFloat(viewModel.audioLevel))
                    .animation(.easeInOut(duration: 0.05), value: viewModel.audioLevel)
                    .padding()
            }
            
            ScrollView {
                Text(viewModel.transcript)
                    .padding()
                    .textSelection(.enabled)  // Enable selectable text
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}
