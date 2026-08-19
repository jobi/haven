import SwiftUI

public struct MediaControlCardView: View {
    let config: MediaControlCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    @State private var localVolume: Double? = nil
    @State private var isDraggingVolume: Bool = false
    
    public init(
        config: MediaControlCardConfig?,
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil
    ) {
        self.config = config
        self.entityStore = entityStore
        self.onMoreInfo = onMoreInfo
    }
    
    private var entity: HAEntityState? {
        guard let id = config?.entity else { return nil }
        return entityStore.entity(for: id)
    }
    
    private var entityId: String {
        config?.entity ?? ""
    }
    
    private var state: String {
        entity?.state.lowercased() ?? "off"
    }
    
    private var isPlaying: Bool {
        state == "playing"
    }
    
    private var isPaused: Bool {
        state == "paused"
    }
    
    private var isOff: Bool {
        state == "off" || state == "unavailable"
    }
    
    private var isActive: Bool {
        isPlaying || isPaused || state == "idle" || state == "buffering" || state == "on"
    }
    
    private var displayName: String {
        config?.name ?? entity?.friendlyName ?? config?.entity ?? "Media Player"
    }
    
    private var mediaTitle: String? {
        entity?.attributes["media_title"]?.stringValue
    }
    
    private var mediaArtist: String? {
        entity?.attributes["media_artist"]?.stringValue ??
        entity?.attributes["media_album_name"]?.stringValue ??
        entity?.attributes["app_name"]?.stringValue
    }
    
    private var source: String? {
        entity?.attributes["source"]?.stringValue
    }
    
    private var sourceList: [String] {
        entity?.attributes["source_list"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    }
    
    private var isMuted: Bool {
        entity?.attributes["is_volume_muted"]?.boolValue ?? false
    }
    
    private var currentVolume: Double {
        localVolume ?? entity?.attributes["volume_level"]?.doubleValue ?? 0.0
    }
    
    private var supportedFeatures: Int {
        entity?.attributes["supported_features"]?.intValue ?? 0
    }
    
    // Home Assistant MediaPlayerEntityFeature flags
    private var supportsPlayPause: Bool { (supportedFeatures & 1) != 0 || (supportedFeatures & 16384) != 0 || !isOff }
    private var supportsPrevious: Bool { (supportedFeatures & 16) != 0 }
    private var supportsNext: Bool { (supportedFeatures & 32) != 0 }
    private var supportsVolumeSet: Bool { (supportedFeatures & 4) != 0 }
    private var supportsVolumeMute: Bool { (supportedFeatures & 8) != 0 }
    private var supportsSource: Bool { (supportedFeatures & 2048) != 0 && !sourceList.isEmpty }
    
    private var artworkURL: URL? {
        guard let pic = entity?.attributes["entity_picture"]?.stringValue else { return nil }
        if pic.hasPrefix("http://") || pic.hasPrefix("https://") {
            return URL(string: pic)
        }
        if let base = entityStore.serverURL {
            return URL(string: pic, relativeTo: base)
        }
        return nil
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Top Section: Artwork / Icon + Title & Secondary Info + Power Button
            HStack(spacing: 12) {
                // Artwork / Icon Badge
                Button {
                    if let id = config?.entity {
                        onMoreInfo?(id)
                    }
                } label: {
                    if let artwork = artworkURL, isActive {
                        AsyncImage(url: artwork) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            default:
                                fallbackIcon
                            }
                        }
                    } else {
                        fallbackIcon
                    }
                }
                .buttonStyle(.plain)
                
                // Track / Device Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(mediaTitle ?? displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let id = config?.entity {
                        onMoreInfo?(id)
                    }
                }
                
                // Source Selector (if available) & Power Button
                HStack(spacing: 8) {
                    if supportsSource {
                        Menu {
                            ForEach(sourceList, id: \.self) { item in
                                Button {
                                    Task {
                                        await entityStore.selectSource(entityId: entityId, source: item)
                                    }
                                } label: {
                                    HStack {
                                        Text(item)
                                        if item == source {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(source ?? "Source")
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Power Button
                    Button {
                        Task {
                            await entityStore.toggle(entityId: entityId)
                        }
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isOff ? Color.secondary : Color.haBlue)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isOff ? Color.primary.opacity(0.05) : Color.haBlue.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Playback Controls Row (if active or turned on)
            if !isOff {
                HStack(spacing: 24) {
                    Spacer()
                    
                    // Previous Track Button
                    Button {
                        Task {
                            await entityStore.mediaPreviousTrack(entityId: entityId)
                        }
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(supportsPrevious ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(!supportsPrevious)
                    
                    // Main Play/Pause/Stop Button
                    Button {
                        Task {
                            await entityStore.mediaPlayPause(entityId: entityId)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.haBlue)
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.haBlue.opacity(0.3), radius: 4, y: 2)
                            
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Next Track Button
                    Button {
                        Task {
                            await entityStore.mediaNextTrack(entityId: entityId)
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(supportsNext ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(!supportsNext)
                    
                    Spacer()
                }
                .padding(.top, 2)
                
                // Volume Slider Row
                if supportsVolumeSet || supportsVolumeMute {
                    HStack(spacing: 12) {
                        // Mute Button
                        Button {
                            Task {
                                await entityStore.setVolumeMute(entityId: entityId, isMuted: !isMuted)
                            }
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : volumeIconName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isMuted ? Color.red : Color.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        
                        // Volume Slider Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background Track
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 8)
                                
                                // Active Fill Track
                                Capsule()
                                    .fill(isMuted ? Color.secondary.opacity(0.3) : Color.haBlue)
                                    .frame(width: max(8, geo.size.width * CGFloat(currentVolume)), height: 8)
                            }
                            .frame(height: geo.size.height)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDraggingVolume = true
                                        let fraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                                        localVolume = Double(fraction)
                                    }
                                    .onEnded { value in
                                        let fraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                                        let finalVol = Double(fraction)
                                        localVolume = finalVol
                                        isDraggingVolume = false
                                        Task {
                                            await entityStore.setVolume(entityId: entityId, level: finalVol)
                                        }
                                    }
                            )
                        }
                        .frame(height: 24)
                        
                        // Volume Percentage Label
                        Text("\(Int(currentVolume * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color.haCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
    
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPlaying ? Color.haBlue.opacity(0.15) : Color.primary.opacity(0.06))
                .frame(width: 44, height: 44)
            
            HAIconView(
                icon: config?.icon ?? entity?.icon,
                domain: "media_player",
                isActive: isActive,
                fallbackSymbol: defaultDeviceSymbol
            )
            .frame(width: 22, height: 22)
            .foregroundStyle(isPlaying ? Color.haBlue : Color.secondary)
        }
    }
    
    private var defaultDeviceSymbol: String {
        let devClass = entity?.attributes["device_class"]?.stringValue
        switch devClass {
        case "tv": return "tv"
        case "speaker": return "speaker.wave.2.fill"
        case "receiver": return "hifispeaker.fill"
        default: return "play.tv.fill"
        }
    }
    
    private var subtitleText: String {
        if mediaTitle != nil, let artist = mediaArtist {
            return artist
        }
        if let src = source, !src.isEmpty {
            return src
        }
        return state.capitalized
    }
    
    private var volumeIconName: String {
        if currentVolume == 0 {
            return "speaker.fill"
        } else if currentVolume < 0.33 {
            return "speaker.wave.1.fill"
        } else if currentVolume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
