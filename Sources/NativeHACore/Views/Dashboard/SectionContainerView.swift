import SwiftUI

public struct SectionContainerView: View {
    let section: LovelaceSection
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    public init(
        section: LovelaceSection,
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil
    ) {
        self.section = section
        self.entityStore = entityStore
        self.onMoreInfo = onMoreInfo
    }
    
    public var body: some View {
        let visibleCards = section.cards.filter {
            VisibilityEvaluator.isVisible(visibility: $0.visibility, entityStore: entityStore)
        }
        let firstCardIsHeading = visibleCards.first?.type == "heading"
        
        VStack(alignment: .leading, spacing: 12) {
            // Optional Section Title / Header (Only if the first card is NOT a heading card)
            if !firstCardIsHeading, let title = section.title, !title.isEmpty {
                HStack(spacing: 8) {
                    if let icon = section.icon {
                        Image(systemName: IconMapper.sfSymbol(for: icon))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            
            // Section Cards Stack (Filtered by visibility and arranged in 2-column grid)
            let blocks = groupIntoBlocks(cards: visibleCards)
            
            VStack(spacing: 12) {
                ForEach(blocks) { block in
                    switch block {
                    case .fullWidth(let cardConfig):
                        CardViewFactory.buildCard(
                            config: cardConfig,
                            entityStore: entityStore,
                            sectionTitle: section.title,
                            onMoreInfo: onMoreInfo
                        )
                        
                    case .halfWidthGrid(let gridCards):
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 100), spacing: 12, alignment: .top),
                                GridItem(.flexible(minimum: 100), spacing: 12, alignment: .top)
                            ],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            ForEach(gridCards) { cardConfig in
                                CardViewFactory.buildCard(
                                    config: cardConfig,
                                    entityStore: entityStore,
                                    sectionTitle: section.title,
                                    onMoreInfo: onMoreInfo
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private func groupIntoBlocks(cards: [AnyCardConfig]) -> [CardLayoutBlock] {
        var blocks: [CardLayoutBlock] = []
        var currentGrid: [AnyCardConfig] = []
        
        for card in cards {
            if card.columnSpan == 2 {
                if !currentGrid.isEmpty {
                    blocks.append(.halfWidthGrid(currentGrid))
                    currentGrid.removeAll()
                }
                blocks.append(.fullWidth(card))
            } else {
                currentGrid.append(card)
            }
        }
        
        if !currentGrid.isEmpty {
            blocks.append(.halfWidthGrid(currentGrid))
        }
        
        return blocks
    }
}

private enum CardLayoutBlock: Identifiable {
    case fullWidth(AnyCardConfig)
    case halfWidthGrid([AnyCardConfig])
    
    var id: String {
        switch self {
        case .fullWidth(let card):
            return "full_" + card.id
        case .halfWidthGrid(let cards):
            return "grid_" + (cards.first?.id ?? UUID().uuidString)
        }
    }
}
