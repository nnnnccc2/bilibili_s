import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "apple.logo")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Hello, iOS 18!")
                .font(.largeTitle.bold())

            Text("SwiftUI · Xcode 16 · iOS 18")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Tap Me") {
                print("Hello from iOS 18 🎉")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
