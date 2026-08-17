import SwiftUI

@MainActor
public struct CardViewFactory {
    
    @ViewBuilder
    public static func buildCard(
        config: AnyCardConfig,
        entityStore: EntityStore,
        sectionTitle: String? = nil,
        onMoreInfo: ((String) -> Void)? = nil
    ) -> some View {
        switch config.type {
        case "heading":
            HeadingCardView(
                config: try? config.decode(HeadingCardConfig.self),
                rawConfig: config.rawData,
                entityStore: entityStore,
                sectionTitle: sectionTitle,
                onMoreInfo: onMoreInfo
            )
            
        case "tile":
            TileCardView(
                config: try? config.decode(TileCardConfig.self),
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
            
        case "button":
            ButtonCardView(
                config: try? config.decode(ButtonCardConfig.self),
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
            
        case "entities":
            EntitiesCardView(
                config: try? config.decode(EntitiesCardConfig.self),
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
            
        case "sensor":
            SensorCardView(
                config: try? config.decode(SensorCardConfig.self),
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
            
        case "gauge":
            GaugeCardView(
                config: try? config.decode(GaugeCardConfig.self),
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
            
        case "markdown":
            MarkdownCardView(config: try? config.decode(MarkdownCardConfig.self))
            
        case "media-control":
            MediaControlCardView(
                config: try? config.decode(MediaControlCardConfig.self),
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
            
        case "badge":
            BadgePillView(
                config: config,
                entityStore: entityStore,
                onSelect: onMoreInfo
            )
            
        default:
            UnsupportedCardView(type: config.type, rawConfig: config.rawData)
        }
    }
}
