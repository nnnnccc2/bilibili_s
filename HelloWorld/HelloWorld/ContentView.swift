//
//  ContentView.swift
//  HelloWorld
//
//  iOS 18 SwiftUI Hello World - Main Content View
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 60))

            Text("Hello, World!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("iOS 18 SwiftUI App")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
