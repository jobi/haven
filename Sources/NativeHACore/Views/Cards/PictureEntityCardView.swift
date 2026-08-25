import SwiftUI

public struct PictureEntityCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let entity: String
    public let name: String?
    public let cameraImage: String?
    public let cameraView: String?
    public let showState: Bool?
    public let showName: Bool?
    public let tapAction: ActionConfig?
    
    enum CodingKeys: String, CodingKey {
        case type, entity, name
        case cameraImage = "camera_image"
        case cameraView = "camera_view"
        case showState = "show_state"
        case showName = "show_name"
        case tapAction = "tap_action"
    }
}

public struct PictureEntityCardView: View {
    let config: PictureEntityCardConfig?
    let rawConfig: [String: AnyCodable]
    let entityStore: EntityStore
    let onMoreInfo: ((String) -> Void)?
    
    public init(
        config: PictureEntityCardConfig?,
        rawConfig: [String: AnyCodable] = [:],
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil
    ) {
        self.config = config
        self.rawConfig = rawConfig
        self.entityStore = entityStore
        self.onMoreInfo = onMoreInfo
    }
    
    private var targetEntityId: String {
        config?.entity
            ?? config?.cameraImage
            ?? rawConfig["entity"]?.stringValue
            ?? rawConfig["camera_image"]?.stringValue
            ?? ""
    }
    
    private var entity: HAEntityState? {
        entityStore.entity(for: targetEntityId)
    }
    
    private var displayName: String {
        config?.name ?? rawConfig["name"]?.stringValue ?? entity?.friendlyName ?? targetEntityId
    }
    
    public var body: some View {
        Button {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onMoreInfo?(targetEntityId)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if !targetEntityId.isEmpty {
                    HACameraStreamView(
                        entityId: targetEntityId,
                        entityStore: entityStore,
                        entityPicture: entity?.attributes["entity_picture"]?.stringValue
                    )
                } else {
                    ZStack {
                        Color.black.opacity(0.8)
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Camera Configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
