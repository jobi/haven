import SwiftUI

public struct MarkdownCardView: View {
    let config: MarkdownCardConfig?
    
    public init(config: MarkdownCardConfig?) {
        self.config = config
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = config?.title, !title.isEmpty {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            if let content = config?.content {
                Text(LocalizedStringKey(content))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.haCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
