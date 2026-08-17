import SwiftUI

public struct UnsupportedCardView: View {
    let type: String
    let rawConfig: [String: AnyCodable]
    
    @State private var isExpanded: Bool = false
    
    public init(type: String, rawConfig: [String: AnyCodable] = [:]) {
        self.type = type
        self.rawConfig = rawConfig
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom / Unhandled Card")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("type: \(type)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                Divider()
                
                ScrollView(.horizontal) {
                    Text(formattedRawConfig)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.haCardBackground.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.orange.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
    }
    
    private var formattedRawConfig: String {
        guard let data = try? JSONEncoder().encode(rawConfig),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return "{\n  \"type\": \"\(type)\"\n}"
        }
        return prettyString
    }
}
