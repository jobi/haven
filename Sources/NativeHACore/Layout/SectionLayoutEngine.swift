import SwiftUI

public struct SectionLayoutEngine: Sendable {
    public static let minSectionWidth: CGFloat = 330.0
    public static let sectionSpacing: CGFloat = 16.0
    public static let contentPadding: CGFloat = 16.0

    /// Computes the number of section columns for a given viewport width and max columns clamp
    public static func calculateColumnCount(for totalWidth: CGFloat, maxAllowed: Int? = nil) -> Int {
        guard totalWidth > 0 else { return 1 }
        
        let usableWidth = totalWidth - (contentPadding * 2)
        let possibleColumns = Int((usableWidth + sectionSpacing) / (minSectionWidth + sectionSpacing))
        let calculated = max(1, possibleColumns)
        
        if let maxAllowed = maxAllowed, maxAllowed > 0 {
            return min(calculated, maxAllowed)
        }
        return min(calculated, 4) // Max 4 columns on large displays
    }
    
    /// Generates the GridItem specifications for SwiftUI LazyVGrid
    public static func gridColumns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: minSectionWidth), spacing: sectionSpacing, alignment: .top),
            count: count
        )
    }
}
