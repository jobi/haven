import SwiftUI
import Charts

public struct SensorHistoryChartView: View {
    let historyPoints: [HistoryDataPoint]
    let unit: String?
    let tintColor: Color
    
    @State private var selectedPoint: HistoryDataPoint? = nil
    
    public init(
        historyPoints: [HistoryDataPoint],
        unit: String? = nil,
        tintColor: Color = .haBlue
    ) {
        self.historyPoints = historyPoints
        self.unit = unit
        self.tintColor = tintColor
    }
    
    private var minValue: Double {
        historyPoints.map(\.value).min() ?? 0.0
    }
    
    private var maxValue: Double {
        historyPoints.map(\.value).max() ?? 100.0
    }
    
    private var avgValue: Double {
        guard !historyPoints.isEmpty else { return 0.0 }
        let total = historyPoints.map(\.value).reduce(0, +)
        return total / Double(historyPoints.count)
    }
    
    private var yDomain: ClosedRange<Double> {
        let padding = max(0.5, (maxValue - minValue) * 0.15)
        return max(0, minValue - padding)...(maxValue + padding)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats Summary Header
            HStack {
                statBox(title: "Min", value: minValue)
                Spacer()
                statBox(title: "Average", value: avgValue)
                Spacer()
                statBox(title: "Max", value: maxValue)
            }
            .padding(.horizontal, 4)
            
            // Selected point callout if scrubbing
            if let selected = selectedPoint {
                HStack {
                    Text(selected.timestamp, style: .time)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@", selected.value, unit ?? ""))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(tintColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(tintColor.opacity(0.12))
                )
                .transition(.opacity)
            }
            
            // Interactive SwiftUI Chart
            if !historyPoints.isEmpty {
                Chart {
                    ForEach(historyPoints) { point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.35),
                                    tintColor.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(tintColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                    
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected Time", selected.timestamp))
                            .foregroundStyle(Color.primary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        
                        PointMark(
                            x: .value("Time", selected.timestamp),
                            y: .value("Value", selected.value)
                        )
                        .symbolSize(40)
                        .foregroundStyle(tintColor)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.0f", doubleValue))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let xPos = value.location.x - geo[proxy.plotFrame!].origin.x
                                        if let date: Date = proxy.value(atX: xPos) {
                                            selectedPoint = findClosestPoint(to: date)
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPoint = nil
                                    }
                            )
                    }
                }
                .frame(height: 140)
            } else {
                Text("No history available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 80)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statBox(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f %@", value, unit ?? ""))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
    
    private func findClosestPoint(to date: Date) -> HistoryDataPoint? {
        historyPoints.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }
}
