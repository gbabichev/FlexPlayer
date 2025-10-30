//
//  MetadataSearchView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
struct MetadataSearchView: View {
    let movieName: String
    let onSelect: (UnifiedMovie) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchResults: [UnifiedMovie] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""

    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    TextField("Search for movie", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }

                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchQuery.isEmpty || isLoading)
                }
                .padding()

                if isLoading {
                    ProgressView("Searching...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            performSearch()
                        }
                    }
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "film.stack")
                    } description: {
                        Text("No movies found for '\(searchQuery)'")
                    }
                } else if searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("Search for Movies", systemImage: "magnifyingglass")
                    } description: {
                        Text("Enter a movie title to search")
                    }
                } else {
                    List(searchResults, id: \.id) { movie in
                        Button(action: {
                            onSelect(movie)
                            dismiss()
                        }) {
                            MovieSearchResultRow(movie: movie)
                        }
                    }
                }
            }
            .navigationTitle("Re-match Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                print("📱 MetadataSearchView appeared for: \(movieName)")
                // Pre-fill search with cleaned movie name
                searchQuery = cleanMovieTitle(movieName)
                print("📱 Search query set to: \(searchQuery)")
                performSearch()
            }
        }
    }

    private func performSearch() {
        print("🔎 performSearch called with query: '\(searchQuery)'")
        guard !searchQuery.isEmpty else {
            print("⚠️ Search query is empty, returning")
            return
        }

        isLoading = true
        errorMessage = nil
        print("🔎 Starting search...")

        Task {
            do {
                print("🔎 Calling MetadataService.searchMovies...")
                let results = try await MetadataService.shared.searchMovies(title: searchQuery, limit: 10)
                print("🔎 Got \(results.count) results")
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                    print("🔎 UI updated with results")
                }
            } catch {
                print("❌ Search error: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func cleanMovieTitle(_ filename: String) -> String {
        var title = filename

        // Remove file extension
        if let lastDot = title.lastIndex(of: ".") {
            title = String(title[..<lastDot])
        }

        // Remove year in parentheses or brackets
        title = title.replacingOccurrences(of: #"\s*[\(\[]\d{4}[\)\]]"#, with: "", options: .regularExpression)

        // Remove common quality indicators
        let qualityPatterns = ["1080p", "720p", "2160p", "4K", "BluRay", "WEB-DL", "WEBRip", "HDRip", "BRRip"]
        for pattern in qualityPatterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }

        // Replace dots, underscores with spaces
        title = title.replacingOccurrences(of: ".", with: " ")
        title = title.replacingOccurrences(of: "_", with: " ")

        // Trim whitespace
        title = title.trimmingCharacters(in: .whitespaces)

        return title
    }
}
