//
//  ShowMetadataSearchView.swift
//  FlexPlayer
//

import SwiftUI

struct ShowMetadataSearchView: View {
    let showName: String
    let onSelect: (UnifiedShow) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchResults: [UnifiedShow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Search for show", text: $searchQuery)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
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
                        Label("No Results", systemImage: "tv")
                    } description: {
                        Text("No shows found for '\(searchQuery)'")
                    }
                } else if searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("Search for Shows", systemImage: "magnifyingglass")
                    } description: {
                        Text("Enter a show title to search")
                    }
                } else {
                    List(searchResults, id: \.id) { show in
                        Button(action: {
                            onSelect(show)
                            dismiss()
                        }) {
                            ShowSearchResultRow(show: show)
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
                print("📺 ShowMetadataSearchView appeared for: \(showName)")
                searchQuery = cleanShowTitle(showName)
                print("📺 Search query set to: \(searchQuery)")
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
                print("🔎 Calling MetadataService.searchShows...")
                let results = try await MetadataService.shared.searchShows(name: searchQuery, limit: 10)
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

    private func cleanShowTitle(_ name: String) -> String {
        var title = name

        if let lastDot = title.lastIndex(of: ".") {
            title = String(title[..<lastDot])
        }

        title = title.replacingOccurrences(of: #"\s*[\(\[]\d{4}[\)\]]"#, with: "", options: .regularExpression)

        let qualityPatterns = ["1080p", "720p", "2160p", "4K", "BluRay", "WEB-DL", "WEBRip", "HDRip", "BRRip"]
        for pattern in qualityPatterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }

        title = title.replacingOccurrences(of: ".", with: " ")
        title = title.replacingOccurrences(of: "_", with: " ")

        title = title.trimmingCharacters(in: .whitespaces)

        return title
    }
}
