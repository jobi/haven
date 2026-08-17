import SwiftUI

public struct HeadingCardView: View {
    let config: HeadingCardConfig?
    let rawConfig: [String: AnyCodable]?
    let entityStore: EntityStore?
    var sectionTitle: String? = nil
    var onMoreInfo: ((String) -> Void)?
    
    public init(
        config: HeadingCardConfig?,
        rawConfig: [String: AnyCodable]? = nil,
        entityStore: EntityStore? = nil,
        sectionTitle: String? = nil,
        onMoreInfo: ((String) -> Void)? = nil
    ) {
        self.config = config
        self.rawConfig = rawConfig
        self.entityStore = entityStore
        self.sectionTitle = sectionTitle
        self.onMoreInfo = onMoreInfo
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon = resolvedIcon {
                Image(systemName: IconMapper.sfSymbol(for: icon))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            let text = resolvedTitle
            if !text.isEmpty {
                Text(text)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .layoutPriority(2)
            }
            
            Spacer(minLength: 4)
            
            if let badges = resolvedBadges, let store = entityStore {
                let visibleBadges = badges.filter {
                    VisibilityEvaluator.isVisible(visibility: $0.visibility, entityStore: store)
                }
                if !visibleBadges.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(visibleBadges) { badge in
                            BadgePillView(
                                config: badge,
                                entityStore: store,
                                onSelect: onMoreInfo
                            )
                        }
                    }
                    .layoutPriority(1)
                }
            }
        }
        .frame(height: 34)
        .padding(.horizontal, 4)
    }
    
    private var resolvedTitle: String {
        if let h = config?.displayText, !h.isEmpty { return h }
        if let headingVal = rawConfig?["heading"] {
            if let str = headingVal.stringValue, !str.isEmpty { return str }
            if let text = headingVal.dictionaryValue?["text"]?.stringValue, !text.isEmpty { return text }
            if let name = headingVal.dictionaryValue?["name"]?.stringValue, !name.isEmpty { return name }
        }
        for key in ["title", "name", "text", "label", "content", "heading_text"] {
            if let val = rawConfig?[key]?.stringValue, !val.isEmpty {
                return val
            }
        }
        if let st = sectionTitle, !st.isEmpty {
            return st
        }
        return ""
    }
    
    private var resolvedIcon: String? {
        config?.icon ?? rawConfig?["icon"]?.stringValue
    }
    
    private var resolvedBadges: [AnyCardConfig]? {
        config?.badges
    }
}
