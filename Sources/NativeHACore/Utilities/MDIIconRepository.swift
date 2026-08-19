import Foundation
import CoreGraphics
import SwiftUI

/// Thread-safe singleton repository that provides access to all 7,400+ Material Design Icons (MDI).
public final class MDIIconRepository: @unchecked Sendable {
    public static let shared = MDIIconRepository()
    
    private let lock = NSLock()
    private var iconPaths: [String: String] = [:]
    private var isLoaded: Bool = false
    
    // In-memory cache for parsed CGPath instances
    private let pathCache = NSCache<NSString, AnyObject>()
    
    public init() {}
    
    /// Returns the parsed CGPath for an MDI icon name (with or without "mdi:" prefix), scaled for a 24x24 viewport.
    public func path(for name: String) -> CGPath? {
        let cleanName = normalizeIconName(name)
        let cacheKey = cleanName as NSString
        
        if let cached = pathCache.object(forKey: cacheKey) {
            return (cached as! CGPathWrapper).cgPath
        }
        
        ensureLoaded()
        
        lock.lock()
        let svgString = iconPaths[cleanName]
        lock.unlock()
        
        guard let svg = svgString, let cgPath = SVGPathParser.parse(svgPath: svg) else {
            return nil
        }
        
        pathCache.setObject(CGPathWrapper(cgPath: cgPath), forKey: cacheKey)
        return cgPath
    }
    
    /// Checks if an icon exists in the MDI database.
    public func hasIcon(name: String) -> Bool {
        let cleanName = normalizeIconName(name)
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return iconPaths[cleanName] != nil
    }
    
    /// Normalizes "mdi:fireplace" or "mdi:ceiling-light" to "fireplace", "ceiling-light"
    private func normalizeIconName(_ name: String) -> String {
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.hasPrefix("mdi:") {
            clean = String(clean.dropFirst(4))
        }
        return clean
    }
    
    private func ensureLoaded() {
        lock.lock()
        if isLoaded {
            lock.unlock()
            return
        }
        lock.unlock()
        
        loadIcons()
    }
    
    private func loadIcons() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isLoaded else { return }
        
        var jsonURL: URL? = nil
        
        #if SWIFT_PACKAGE
        jsonURL = Bundle.module.url(forResource: "mdi_icons", withExtension: "json")
        #endif
        
        if jsonURL == nil {
            jsonURL = Bundle.main.url(forResource: "mdi_icons", withExtension: "json")
        }
        
        // Fallback for tests or direct bundle loading
        if jsonURL == nil {
            for b in Bundle.allBundles + Bundle.allFrameworks {
                if let u = b.url(forResource: "mdi_icons", withExtension: "json") {
                    jsonURL = u
                    break
                }
            }
        }
        
        guard let url = jsonURL, let data = try? Data(contentsOf: url) else {
            print("[MDIIconRepository] Warning: Could not locate mdi_icons.json bundle resource.")
            self.isLoaded = true
            return
        }
        
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            self.iconPaths = dict
        }
        
        self.isLoaded = true
    }
}

// Wrapper for NSCache storage of CGPath
private final class CGPathWrapper: @unchecked Sendable {
    let cgPath: CGPath
    init(cgPath: CGPath) {
        self.cgPath = cgPath
    }
}
