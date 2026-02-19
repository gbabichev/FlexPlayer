import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TutorialView: View {
    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let systemImage: String
        let linkText: String?
        let linkURL: String?

        init(
            title: String,
            message: String,
            systemImage: String,
            linkText: String? = nil,
            linkURL: String? = nil
        ) {
            self.title = title
            self.message = message
            self.systemImage = systemImage
            self.linkText = linkText
            self.linkURL = linkURL
        }
    }

    @Binding var isPresented: Bool
    @State private var index = 0

    private let steps: [Step] = [
        Step(
            title: "Welcome to FlexPlayer",
            message: "Tap Continue to get started.",
            systemImage: "hand.wave"
        ),
        Step(
            title: "Organize Your Library",
            message: "Add supported video files with the Files app, or with Finder on macOS.",
            systemImage: "folder.fill",
            linkText: "Learn More",
            linkURL: "https://gbabichev.github.io/FlexPlayer/Documentation/Support.html#transfer-files"
        ),
        Step(
            title: "Rich Metadata",
            message: "Use Fetch Metadata in Settings to pull rich info for your library.",
            systemImage: "info.circle.fill"
        ),
        Step(
            title: "Track Your Progress",
            message: "Watch progress is saved automatically so you can continue where you left off.",
            systemImage: "bookmark.fill"
        ),
        Step(
            title: "Help?",
            message: "Check out the website for more information about Flex Player.",
            systemImage: "questionmark.circle",
            linkText: "Visit Website",
            linkURL: "https://gbabichev.github.io/FlexPlayer/Documentation/Support.html"
        )
    ]

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("Welcome to FlexPlayer")
                        .font(.headline)
                    Spacer()
                    Button("Skip") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
#if os(macOS)
                    .keyboardShortcut(.cancelAction)
#endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                TabView(selection: $index) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        TutorialStepCard(step: step)
                            .padding(.horizontal, 20)
#if os(macOS)
                            .tabItem { Text(step.title) }
#endif
                            .tag(idx)
                    }
                }
                .modifier(TutorialPagingStyle())
                .animation(.easeInOut(duration: 0.2), value: index)

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(steps.indices, id: \.self) { idx in
                            Capsule()
                                .fill(idx == index ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: idx == index ? 22 : 8, height: 8)
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: index)

                    Text("Step \(index + 1) of \(steps.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(index == steps.count - 1 ? "Get Started" : "Continue") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
#if os(macOS)
                .keyboardShortcut(.defaultAction)
#endif
            }
        }
#if os(macOS)
        .frame(minWidth: 700, minHeight: 520)
#endif
    }

    private var backgroundGradient: LinearGradient {
#if os(iOS)
        return LinearGradient(
            colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
#else
        return LinearGradient(
            colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom
        )
#endif
    }

    private func advance() {
        if index == steps.count - 1 {
            isPresented = false
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            index += 1
        }
    }
}

private struct TutorialPagingStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        content.tabViewStyle(.page(indexDisplayMode: .never))
#else
        content
#endif
    }
}

private struct TutorialStepCard: View {
    let step: TutorialView.Step

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 110, height: 110)
                Image(systemName: step.systemImage)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 14)

            Text(step.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(step.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if let linkText = step.linkText,
               let linkURL = step.linkURL,
               let url = URL(string: linkURL) {
                Link(linkText, destination: url)
                    .font(.subheadline)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    TutorialView(isPresented: .constant(true))
}
