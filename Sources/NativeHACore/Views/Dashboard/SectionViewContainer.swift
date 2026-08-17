import SwiftUI

public struct SectionViewContainer: View {
    let viewConfig: LovelaceView
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    var onRefresh: (() async -> Void)?
    
    public init(
        viewConfig: LovelaceView,
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.viewConfig = viewConfig
        self.entityStore = entityStore
        self.onMoreInfo = onMoreInfo
        self.onRefresh = onRefresh
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let columnCount = SectionLayoutEngine.calculateColumnCount(
                for: geometry.size.width,
                maxAllowed: viewConfig.maxColumns
            )
            
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    // Top Badges Shelf (Filtered by visibility)
                    let visibleBadges = (viewConfig.badges ?? []).filter {
                        VisibilityEvaluator.isVisible(visibility: $0.visibility, entityStore: entityStore)
                    }
                    
                    if !visibleBadges.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(visibleBadges) { badge in
                                    BadgePillView(
                                        config: badge,
                                        entityStore: entityStore,
                                        onSelect: onMoreInfo
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                    
                    // Adaptive Sections Grid (Filtered by visibility)
                    let visibleSections = (viewConfig.sections ?? []).filter { section in
                        guard VisibilityEvaluator.isVisible(visibility: section.visibility, entityStore: entityStore) else {
                            return false
                        }
                        let hasVisibleCards = section.cards.contains {
                            VisibilityEvaluator.isVisible(visibility: $0.visibility, entityStore: entityStore)
                        }
                        let hasTitle = !(section.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        return hasVisibleCards || hasTitle
                    }
                    
                    if !visibleSections.isEmpty {
                        LazyVGrid(
                            columns: SectionLayoutEngine.gridColumns(count: columnCount),
                            alignment: .leading,
                            spacing: SectionLayoutEngine.sectionSpacing
                        ) {
                            ForEach(visibleSections) { section in
                                SectionContainerView(
                                    section: section,
                                    entityStore: entityStore,
                                    onMoreInfo: onMoreInfo
                                )
                            }
                        }
                        .padding(.horizontal, SectionLayoutEngine.contentPadding)
                        .padding(.bottom, 48)
                    } else {
                        // Empty Section View State
                        VStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text("No sections configured in this view")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    }
                }
                .frame(minWidth: geometry.size.width, alignment: .topLeading)
            }
            .background(Color.haBackground)
            .refreshable {
                if let onRefresh = onRefresh {
                    await onRefresh()
                }
            }
        }
    }
}
