import Foundation
import CoreGraphics
import SwiftUI

/// High-performance parser that converts SVG path data strings into `CGPath` and SwiftUI `Path`.
public struct SVGPathParser: Sendable {
    
    public static func parse(svgPath: String) -> CGPath? {
        var scanner = SVGScanner(string: svgPath)
        let path = CGMutablePath()
        
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControlPoint: CGPoint? = nil
        var lastCommand: Character? = nil
        
        while let command = scanner.scanCommand() {
            let isRelative = command.isLowercase
            let cmd = command.uppercased().first ?? " "
            
            switch cmd {
            case "M":
                var isFirst = true
                while let p = scanner.scanPoint() {
                    let target = isRelative ? CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y) : p
                    if isFirst {
                        path.move(to: target)
                        subpathStart = target
                        currentPoint = target
                        isFirst = false
                    } else {
                        path.addLine(to: target)
                        currentPoint = target
                    }
                    lastControlPoint = nil
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "L":
                while let p = scanner.scanPoint() {
                    let target = isRelative ? CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y) : p
                    path.addLine(to: target)
                    currentPoint = target
                    lastControlPoint = nil
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "H":
                while let x = scanner.scanDouble() {
                    let targetX = isRelative ? currentPoint.x + CGFloat(x) : CGFloat(x)
                    currentPoint = CGPoint(x: targetX, y: currentPoint.y)
                    path.addLine(to: currentPoint)
                    lastControlPoint = nil
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "V":
                while let y = scanner.scanDouble() {
                    let targetY = isRelative ? currentPoint.y + CGFloat(y) : CGFloat(y)
                    currentPoint = CGPoint(x: currentPoint.x, y: targetY)
                    path.addLine(to: currentPoint)
                    lastControlPoint = nil
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "C":
                while let cp1 = scanner.scanPoint(),
                      let cp2 = scanner.scanPoint(),
                      let endP = scanner.scanPoint() {
                    let c1 = isRelative ? CGPoint(x: currentPoint.x + cp1.x, y: currentPoint.y + cp1.y) : cp1
                    let c2 = isRelative ? CGPoint(x: currentPoint.x + cp2.x, y: currentPoint.y + cp2.y) : cp2
                    let target = isRelative ? CGPoint(x: currentPoint.x + endP.x, y: currentPoint.y + endP.y) : endP
                    
                    path.addCurve(to: target, control1: c1, control2: c2)
                    lastControlPoint = c2
                    currentPoint = target
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "S":
                while let cp2 = scanner.scanPoint(),
                      let endP = scanner.scanPoint() {
                    let c1: CGPoint
                    if let lastCmd = lastCommand, (lastCmd == "C" || lastCmd == "c" || lastCmd == "S" || lastCmd == "s"), let lastCP = lastControlPoint {
                        c1 = CGPoint(x: 2 * currentPoint.x - lastCP.x, y: 2 * currentPoint.y - lastCP.y)
                    } else {
                        c1 = currentPoint
                    }
                    let c2 = isRelative ? CGPoint(x: currentPoint.x + cp2.x, y: currentPoint.y + cp2.y) : cp2
                    let target = isRelative ? CGPoint(x: currentPoint.x + endP.x, y: currentPoint.y + endP.y) : endP
                    
                    path.addCurve(to: target, control1: c1, control2: c2)
                    lastControlPoint = c2
                    currentPoint = target
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "Q":
                while let cp = scanner.scanPoint(),
                      let endP = scanner.scanPoint() {
                    let c = isRelative ? CGPoint(x: currentPoint.x + cp.x, y: currentPoint.y + cp.y) : cp
                    let target = isRelative ? CGPoint(x: currentPoint.x + endP.x, y: currentPoint.y + endP.y) : endP
                    
                    path.addQuadCurve(to: target, control: c)
                    lastControlPoint = c
                    currentPoint = target
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "T":
                while let endP = scanner.scanPoint() {
                    let c: CGPoint
                    if let lastCmd = lastCommand, (lastCmd == "Q" || lastCmd == "q" || lastCmd == "T" || lastCmd == "t"), let lastCP = lastControlPoint {
                        c = CGPoint(x: 2 * currentPoint.x - lastCP.x, y: 2 * currentPoint.y - lastCP.y)
                    } else {
                        c = currentPoint
                    }
                    let target = isRelative ? CGPoint(x: currentPoint.x + endP.x, y: currentPoint.y + endP.y) : endP
                    
                    path.addQuadCurve(to: target, control: c)
                    lastControlPoint = c
                    currentPoint = target
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "A":
                while let rxVal = scanner.scanDouble(),
                      let ryVal = scanner.scanDouble(),
                      let rotVal = scanner.scanDouble(),
                      let largeArcVal = scanner.scanDouble(),
                      let sweepVal = scanner.scanDouble(),
                      let endP = scanner.scanPoint() {
                    let target = isRelative ? CGPoint(x: currentPoint.x + endP.x, y: currentPoint.y + endP.y) : endP
                    
                    addArc(
                        to: path,
                        currentPoint: currentPoint,
                        target: target,
                        rx: CGFloat(abs(rxVal)),
                        ry: CGFloat(abs(ryVal)),
                        xAxisRotation: CGFloat(rotVal),
                        largeArc: largeArcVal != 0,
                        sweep: sweepVal != 0
                    )
                    
                    currentPoint = target
                    lastControlPoint = nil
                    if !scanner.hasMoreNumbers() { break }
                }
                
            case "Z":
                path.closeSubpath()
                currentPoint = subpathStart
                lastControlPoint = nil
                
            default:
                break
            }
            
            lastCommand = command
        }
        
        return path
    }
    
    // MARK: - SVG Arc to Cubic Bezier Conversion
    private static func addArc(
        to path: CGMutablePath,
        currentPoint: CGPoint,
        target: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        xAxisRotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        guard rx > 0, ry > 0, currentPoint != target else {
            path.addLine(to: target)
            return
        }
        
        let phi = xAxisRotation * .pi / 180.0
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        
        let dx = (currentPoint.x - target.x) / 2.0
        let dy = (currentPoint.y - target.y) / 2.0
        let x1Prime = cosPhi * dx + sinPhi * dy
        let y1Prime = -sinPhi * dx + cosPhi * dy
        
        var rx = rx
        var ry = ry
        let lambda = (x1Prime * x1Prime) / (rx * rx) + (y1Prime * y1Prime) / (ry * ry)
        if lambda > 1 {
            let factor = sqrt(lambda)
            rx *= factor
            ry *= factor
        }
        
        let sign: CGFloat = (largeArc == sweep) ? -1.0 : 1.0
        let sqNumerator = max(0, (rx * rx * ry * ry) - (rx * rx * y1Prime * y1Prime) - (ry * ry * x1Prime * x1Prime))
        let sqDenominator = (rx * rx * y1Prime * y1Prime) + (ry * ry * x1Prime * x1Prime)
        let sqFactor = (sqDenominator == 0) ? 0 : sqrt(sqNumerator / sqDenominator)
        
        let cxPrime = sign * sqFactor * (rx * y1Prime / ry)
        let cyPrime = sign * sqFactor * -(ry * x1Prime / rx)
        
        let cx = cosPhi * cxPrime - sinPhi * cyPrime + (currentPoint.x + target.x) / 2.0
        let cy = sinPhi * cxPrime + cosPhi * cyPrime + (currentPoint.y + target.y) / 2.0
        
        func angle(u: CGPoint, v: CGPoint) -> CGFloat {
            let dot = u.x * v.x + u.y * v.y
            let len = sqrt(u.x * u.x + u.y * u.y) * sqrt(v.x * v.x + v.y * v.y)
            let ang = acos(max(-1.0, min(1.0, dot / len)))
            return (u.x * v.y - u.y * v.x < 0) ? -ang : ang
        }
        
        let theta1 = angle(
            u: CGPoint(x: 1, y: 0),
            v: CGPoint(x: (x1Prime - cxPrime) / rx, y: (y1Prime - cyPrime) / ry)
        )
        var dTheta = angle(
            u: CGPoint(x: (x1Prime - cxPrime) / rx, y: (y1Prime - cyPrime) / ry),
            v: CGPoint(x: (-x1Prime - cxPrime) / rx, y: (-y1Prime - cyPrime) / ry)
        )
        
        if !sweep && dTheta > 0 {
            dTheta -= 2 * .pi
        } else if sweep && dTheta < 0 {
            dTheta += 2 * .pi
        }
        
        // Approximate arc segment with cubic beziers
        let segments = max(1, Int(ceil(abs(dTheta) / (.pi / 2.0))))
        let deltaTheta = dTheta / CGFloat(segments)
        let alpha = sin(deltaTheta) * (sqrt(4 + 3 * tan(deltaTheta / 2.0) * tan(deltaTheta / 2.0)) - 1) / 3.0
        
        var currentAngle = theta1
        for _ in 0..<segments {
            let nextAngle = currentAngle + deltaTheta
            
            let cosCurrent = cos(currentAngle)
            let sinCurrent = sin(currentAngle)
            let cosNext = cos(nextAngle)
            let sinNext = sin(nextAngle)
            
            let ep1 = CGPoint(
                x: cosPhi * rx * cosCurrent - sinPhi * ry * sinCurrent + cx,
                y: sinPhi * rx * cosCurrent + cosPhi * ry * sinCurrent + cy
            )
            let ep2 = CGPoint(
                x: cosPhi * rx * cosNext - sinPhi * ry * sinNext + cx,
                y: sinPhi * rx * cosNext + cosPhi * ry * sinNext + cy
            )
            
            let dCurrent = CGPoint(
                x: -cosPhi * rx * sinCurrent - sinPhi * ry * cosCurrent,
                y: -sinPhi * rx * sinCurrent + cosPhi * ry * cosCurrent
            )
            let dNext = CGPoint(
                x: -cosPhi * rx * sinNext - sinPhi * ry * cosNext,
                y: -sinPhi * rx * sinNext + cosPhi * ry * cosNext
            )
            
            let cp1 = CGPoint(x: ep1.x + alpha * dCurrent.x, y: ep1.y + alpha * dCurrent.y)
            let cp2 = CGPoint(x: ep2.x - alpha * dNext.x, y: ep2.y - alpha * dNext.y)
            
            path.addCurve(to: ep2, control1: cp1, control2: cp2)
            currentAngle = nextAngle
        }
    }
}

// MARK: - Fast Character-level Scanner for SVG Path Tokens
private struct SVGScanner {
    private let chars: [Character]
    private var index: Int = 0
    
    init(string: String) {
        self.chars = Array(string)
    }
    
    mutating func scanCommand() -> Character? {
        skipSeparators()
        guard index < chars.count else { return nil }
        let c = chars[index]
        if c.isLetter {
            index += 1
            return c
        }
        return nil
    }
    
    mutating func scanPoint() -> CGPoint? {
        guard let x = scanDouble(), let y = scanDouble() else { return nil }
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    mutating func scanDouble() -> Double? {
        skipSeparators()
        guard index < chars.count else { return nil }
        
        let start = index
        var hasDecimal = false
        var hasExponent = false
        
        if chars[index] == "+" || chars[index] == "-" {
            index += 1
        }
        
        var hasDigits = false
        while index < chars.count {
            let c = chars[index]
            if c.isNumber {
                hasDigits = true
                index += 1
            } else if c == "." && !hasDecimal && !hasExponent {
                hasDecimal = true
                index += 1
            } else if (c == "e" || c == "E") && !hasExponent && hasDigits {
                hasExponent = true
                index += 1
                if index < chars.count && (chars[index] == "+" || chars[index] == "-") {
                    index += 1
                }
            } else {
                break
            }
        }
        
        if index > start && (hasDigits || hasDecimal) {
            let numStr = String(chars[start..<index])
            return Double(numStr)
        }
        
        return nil
    }
    
    func hasMoreNumbers() -> Bool {
        var probe = index
        while probe < chars.count {
            let c = chars[probe]
            if c == "," || c.isWhitespace {
                probe += 1
            } else if c.isNumber || c == "-" || c == "+" || c == "." {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    private mutating func skipSeparators() {
        while index < chars.count {
            let c = chars[index]
            if c == "," || c.isWhitespace {
                index += 1
            } else {
                break
            }
        }
    }
}
