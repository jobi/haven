import SwiftUI
@preconcurrency import CoreGraphics

/// A native SwiftUI view that renders true Material Design Icons (MDI) vector shapes,
/// with seamless fallback to Apple SF Symbols and domain-based glyphs.
public struct HAIconView: View {
    public let icon: String?
    public let domain: String?
    public let isActive: Bool
    public let fallbackSymbol: String?
    
    public init(
        icon: String?,
        domain: String? = nil,
        isActive: Bool = false,
        fallbackSymbol: String? = nil
    ) {
        self.icon = icon
        self.domain = domain
        self.isActive = isActive
        self.fallbackSymbol = fallbackSymbol
    }
    
    public var body: some View {
        if let iconName = icon, !iconName.isEmpty, let mdiPath = resolvedMDIPath(for: iconName) {
            MDIIconShape(cgPath: mdiPath)
                .aspectRatio(1, contentMode: .fit)
        } else {
            let symbol = resolvedSFSymbol
            Image(systemName: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    private func resolvedMDIPath(for name: String) -> CGPath? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("sf:") {
            return nil
        }
        
        // 1. Try explicit active variant if active (e.g. "lightbulb" -> "lightbulb" vs "lightbulb-outline" / "lightbulb-on")
        if isActive {
            if let activePath = MDIIconRepository.shared.path(for: "\(clean)-on") ?? MDIIconRepository.shared.path(for: "\(clean)-active") {
                return activePath
            }
        }
        
        // 2. Direct MDI lookup
        return MDIIconRepository.shared.path(for: clean)
    }
    
    private var resolvedSFSymbol: String {
        if let fb = fallbackSymbol, !fb.isEmpty {
            return fb
        }
        return IconMapper.sfSymbol(for: icon, domain: domain, isActive: isActive)
    }
}

/// SwiftUI Shape that renders a 24x24 MDI CGPath scaled smoothly into any target bounding rect.
public struct MDIIconShape: Shape, @unchecked Sendable {
    public let cgPath: CGPath
    
    public init(cgPath: CGPath) {
        self.cgPath = cgPath
    }
    
    public func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        
        let targetSize = min(rect.width, rect.height)
        let scale = targetSize / 24.0
        
        let offsetX = rect.origin.x + (rect.width - targetSize) / 2.0
        let offsetY = rect.origin.y + (rect.height - targetSize) / 2.0
        
        var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
        
        guard let transformed = cgPath.copy(using: &transform) else {
            return Path(cgPath)
        }
        
        return Path(transformed)
    }
}
