import SwiftUI

public struct AdaptiveGridContainer<Content: View>: View {
    let maxColumns: Int?
    @ViewBuilder let content: (Int) -> Content
    
    public init(
        maxColumns: Int? = nil,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.maxColumns = maxColumns
        self.content = content
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let columnCount = SectionLayoutEngine.calculateColumnCount(
                for: geometry.size.width,
                maxAllowed: maxColumns
            )
            
            content(columnCount)
                .frame(minWidth: geometry.size.width)
        }
    }
}
