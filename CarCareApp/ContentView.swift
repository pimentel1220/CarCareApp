import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var errorCenter: AppErrorCenter
    @EnvironmentObject private var feedbackCenter: AppFeedbackCenter

    var body: some View {
        GarageView()
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
            .overlay(alignment: .top) {
                if let message = feedbackCenter.message {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: feedbackCenter.message)
            .alert("Save Failed", isPresented: Binding(
                get: { errorCenter.message != nil },
                set: { newValue in
                    if !newValue {
                        errorCenter.message = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorCenter.message ?? "Unknown error.")
            }
    }
}
