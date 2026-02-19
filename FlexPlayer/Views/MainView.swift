//
//  ContentView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
import Combine
import AVKit


struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var appState: AppState
    @StateObject var documentManager = DocumentManager()
    @State var selectedItem: SidebarItem?
    @State var selectedVideoURL: URL?
    @State var showingVideoPlayer = false
    @State var selectedMovieThumbnail: Movie?
    @State var selectedMovieThumbnailFileName: String?
    @State var selectedExternalVideoThumbnail: ExternalVideo?
    @State private var isPictureInPictureActive = false
    @State private var showToRematch: ShowToRematch?
    @State private var showSettings = false
    @AppStorage("autoSortEnabled") private var autoSortEnabled = false
    @Query(sort: \ExternalVideo.lastPlayed, order: .reverse) var externalVideos: [ExternalVideo]
    @Query var allEpisodeMetadata: [EpisodeMetadata]
    @Query var allMovieMetadata: [MovieMetadata]

    var sidebarItems: [SidebarItem] {
        var items: [SidebarItem] = documentManager.shows.map { .show($0) }
        if !documentManager.movies.isEmpty {
            items.append(.movies)
        }
        if !externalVideos.isEmpty {
            items.append(.externalVideos)
        }
        return items
    }

    private var detailMetadataRefreshKey: String {
        let showKey = documentManager.shows
            .sorted { $0.name < $1.name }
            .map { show in
                let showStamp = Int(show.metadata?.lastUpdated.timeIntervalSince1970 ?? 0)
                let episodeKey = show.files
                    .sorted { $0.url.path < $1.url.path }
                    .map { file in
                        let episodeStamp = Int(file.metadata?.lastUpdated.timeIntervalSince1970 ?? 0)
                        return "\(file.url.lastPathComponent)#\(episodeStamp)"
                    }
                    .joined(separator: ",")
                return "\(show.name)#\(showStamp)#\(episodeKey)"
            }
            .joined(separator: "|")
        let movieKey = documentManager.movies
            .sorted { $0.url.path < $1.url.path }
            .map { movie in
                let movieStamp = Int(movie.metadata?.lastUpdated.timeIntervalSince1970 ?? 0)
                return "\(movie.name)#\(movieStamp)"
            }
            .joined(separator: "|")
        return "shows{\(showKey)}::movies{\(movieKey)}"
    }
    
    var body: some View {
        NavigationSplitView {
            Group {
                if sidebarItems.isEmpty {
                    GeometryReader { geometry in
                        ScrollView {
                            ContentUnavailableView {
                                Label("No Content", systemImage: "folder")
                            } description: {
                                Text("Use the Files app or your Mac to add content to the Shows and Movies folders")
                            } actions: {
                                Button("Help") {
                                    appState.showTutorial = true
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .refreshable {
                            try? await Task.sleep(nanoseconds: 1_000_000_000 )
                            documentManager.loadDocuments(modelContext: modelContext)
                        }
                    }
                } else {
                    List(sidebarItems, selection: $selectedItem) { item in
                        NavigationLink(value: item) {
                            switch item {
                            case .show(let show):
                                ShowRowView(show: show)
                                    .contextMenu {
                                        Button {
                                            print("🔍 Re-match tapped for show: \(show.name)")
                                            showToRematch = ShowToRematch(name: show.name)
                                        } label: {
                                            Label("Re-match Metadata", systemImage: "magnifyingglass")
                                        }
                                    }
                            case .movies:
                                HStack(spacing: 12) {
                                    // Look up movie by stable fileName instead of using the Movie struct directly
                                    // Fallback to first movie with poster data if no fileName is set
                                    let selectedMovie: Movie? = {
                                        if let fileName = selectedMovieThumbnailFileName,
                                           let movie = documentManager.movies.first(where: { $0.name == fileName }),
                                           movie.metadata?.posterData != nil {
                                            return movie
                                        }
                                        // Fallback: pick first movie with poster data to avoid churn while list updates
                                        return documentManager.movies
                                            .first(where: { $0.metadata?.posterData != nil })
                                    }()

                                    if let movie = selectedMovie,
                                       let posterData = movie.metadata?.posterData,
                                       let uiImage = UIImage(data: posterData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 90)
                                            .cornerRadius(8)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 60, height: 90)
                                            .overlay {
                                                Image(systemName: "film")
                                                    .font(.title)
                                                    .foregroundColor(.blue)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Movies")
                                            .font(.headline)
                                        Text("\(documentManager.movies.count) movie(s)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            case .externalVideos:
                                HStack(spacing: 12) {
                                    Group {
                                        if let video = selectedExternalVideoThumbnail ?? externalVideos.filter({ video in
                                            // Include if has episode still
                                            if let episodeMetadata = getEpisodeMetadataForExternal(video),
                                               episodeMetadata.stillData != nil {
                                                return true
                                            }
                                            // Include if has movie poster
                                            if let movieMetadata = getMovieMetadataForExternal(video),
                                               movieMetadata.posterData != nil {
                                                return true
                                            }
                                            return false
                                        }).randomElement() {
                                            // Try to get episode still first
                                            if let episodeMetadata = getEpisodeMetadataForExternal(video),
                                               let stillData = episodeMetadata.stillData,
                                               let uiImage = UIImage(data: stillData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 120, height: 68)
                                                    .cornerRadius(8)
                                            }
                                            // Fallback to movie poster
                                            else if let movieMetadata = getMovieMetadataForExternal(video),
                                                    let posterData = movieMetadata.posterData,
                                                    let uiImage = UIImage(data: posterData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 60, height: 90)
                                                    .cornerRadius(8)
                                            }
                                            // No metadata, show default icon
                                            else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.purple.opacity(0.3))
                                                    .frame(width: 60, height: 90)
                                                    .overlay {
                                                        Image(systemName: "link")
                                                            .font(.title)
                                                            .foregroundColor(.purple)
                                                    }
                                            }
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.purple.opacity(0.3))
                                                .frame(width: 60, height: 90)
                                                .overlay {
                                                    Image(systemName: "link")
                                                        .font(.title)
                                                        .foregroundColor(.purple)
                                                }
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("External Videos")
                                            .font(.headline)
                                        Text("\(externalVideos.count) video(s)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteAllInItem(item)
                            } label: {
                                Label("Delete All", systemImage: "trash")
                            }
                        }
                    }
                    .refreshable {
                        try? await Task.sleep(nanoseconds: 1_000_000_000 )
                        documentManager.loadDocuments(modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        } detail: {
            Group {
                if let selectedItem = selectedItem {
                    switch selectedItem {
                    case .show(let selectedShow):
                        let liveShow = documentManager.shows.first(where: { $0.name == selectedShow.name }) ?? selectedShow
                        FileListView(
                            show: liveShow,
                            selectedVideoURL: $selectedVideoURL,
                            onRefresh: {
                                refreshAfterDelete()
                            }
                        )
                        .id("show-\(liveShow.name)-\(liveShow.metadata?.lastUpdated.timeIntervalSince1970 ?? 0)-\(liveShow.files.filter { $0.metadata != nil }.count)")
                        .environment(\.modelContext, modelContext)

                    case .movies:
                        MovieListView(
                            movies: documentManager.movies,
                            selectedVideoURL: $selectedVideoURL,
                            onRefresh: {
                                refreshAfterDelete()
                            },
                            onMovieDeleted: { deletedURL in
                                documentManager.movies.removeAll { $0.url == deletedURL }

                                if let currentFileName = selectedMovieThumbnailFileName,
                                   currentFileName == deletedURL.lastPathComponent {
                                    selectedMovieThumbnailFileName = documentManager.movies
                                        .filter({ $0.metadata?.posterData != nil })
                                        .randomElement()?
                                        .name
                                }
                            }
                        )
                        .environment(\.modelContext, modelContext)

                    case .externalVideos:
                        ExternalVideoListView(
                            externalVideos: externalVideos,
                            selectedVideoURL: $selectedVideoURL,
                            onRefresh: {
                                refreshAfterDelete()
                            }
                        )
                        .environment(\.modelContext, modelContext)
                    }
                } else {
                    GeometryReader { geometry in
                        ScrollView {
                            ContentUnavailableView(
                                "Select Content",
                                systemImage: "magnifyingglass",
                                description: Text("Choose a show or Movies from the sidebar")
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .refreshable {
                            try? await Task.sleep(nanoseconds: 1_000_000_000 )
                            documentManager.loadDocuments(modelContext: modelContext)
                        }
                    }
                }
            }
            .id("detail-\(selectedItem?.id ?? "none")-\(detailMetadataRefreshKey)")
        }
        .fullScreenCover(isPresented: $showingVideoPlayer, onDismiss: {
            if !isPictureInPictureActive {
                selectedVideoURL = nil
            }
        }) {
            if let url = selectedVideoURL {
                VideoPlayerView(
                    url: url,
                    playlistURLs: getPlaylistURLs(for: url),
                    currentURL: $selectedVideoURL,
                    onPictureInPictureStarted: {
                        isPictureInPictureActive = true
                        showingVideoPlayer = false
                    },
                    onPictureInPictureStopped: {
                        isPictureInPictureActive = false
                        if !showingVideoPlayer {
                            selectedVideoURL = nil
                        }
                    },
                    onPictureInPictureRestoreRequested: { completionHandler in
                        showingVideoPlayer = true
                        completionHandler(true)
                    }
                )
                .ignoresSafeArea()
                .environment(\.modelContext, modelContext)
            }
        }
        .onChange(of: selectedVideoURL) { oldValue, newValue in
            if newValue != nil && oldValue != newValue {
                showingVideoPlayer = true
            }
        }
        .onAppear {
            setupDocumentsDirectory()
            if autoSortEnabled {
                documentManager.autoSortLibrary(modelContext: modelContext)
            } else {
                documentManager.loadDocuments(modelContext: modelContext)
            }
            selectRandomThumbnails()
        }
        .onChange(of: documentManager.isLoadingMetadata) { oldValue, newValue in
            // When metadata loading finishes, select new random thumbnails
            if oldValue == true && newValue == false {
                selectRandomThumbnails()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlayExternalVideo"))) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                // Only set if not already playing this video
                if selectedVideoURL != url {
                    selectedVideoURL = url
                }
            }
        }
        .sheet(item: $showToRematch) { show in
            ShowMetadataSearchView(showName: show.name) { selectedShow in
                updateShowMetadata(for: show.name, with: selectedShow)
            }
            .onAppear {
                print("📺 Presenting ShowMetadataSearchView for: \(show.name)")
            }
        }
        .onReceive(documentManager.$shows) { _ in
            updateSelection()
        }
        .onReceive(documentManager.$movies) { _ in
            updateSelection()

            if let fileName = selectedMovieThumbnailFileName,
               documentManager.movies.contains(where: { $0.name == fileName && $0.metadata?.posterData != nil }) {
                return
            }

            selectedMovieThumbnailFileName = documentManager.movies
                .filter({ $0.metadata?.posterData != nil })
                .randomElement()?
                .name
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            documentManager.loadDocuments(modelContext: modelContext)
        }) {
            NavigationStack {
                SettingsView(
                    documentManager: documentManager,
                    hasLibraryContent: !sidebarItems.isEmpty,
                    onFetchMetadata: {
                        Task {
                            await documentManager.fetchMetadata(
                                for: documentManager.shows,
                                movies: documentManager.movies,
                                externalVideos: externalVideos,
                                modelContext: modelContext
                            )
                        }
                    },
                    onClearMetadata: {
                        documentManager.clearAllMetadata(modelContext: modelContext)
                    },
                    onSortLibrary: {
                        documentManager.autoSortLibrary(modelContext: modelContext)
                    },
                    onShowTutorial: {
                        appState.showTutorial = true
                    }
                )
            }
        }
    }
    

}
