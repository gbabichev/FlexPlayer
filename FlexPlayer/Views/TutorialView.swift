import SwiftUI

struct TutorialView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [TutorialPage] = [
        TutorialPage(
            icon: "hand.wave",
            title: "Welcome to FlexPlayer",
            description: "Tap Next to get started."
        ),
        TutorialPage(
            icon: "folder.fill",
            title: "Organize Your Library",
            description: "Add your supported video files to FlexPlayer using the Files app, or using Finder on macOS"
        ),
        TutorialPage(
            icon: "info.circle.fill",
            title: "Rich Metadata",
            description: "Tap fetch metadata to get rich information about your content."
        ),
        TutorialPage(
            icon: "bookmark.fill",
            title: "Track Your Progress",
            description: "Your watch progress is automatically saved. Pick up right where you left off."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    TutorialPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Spacer()

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .padding(.bottom, 40)

            HStack {
                Spacer()
                Button("Skip") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.trailing)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: 600, maxHeight: 500)
    }
}

struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .padding(.top, 40)

            Text(page.title)
                .font(.title)
                .fontWeight(.bold)

            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct TutorialPage {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    TutorialView(isPresented: .constant(true))
}
