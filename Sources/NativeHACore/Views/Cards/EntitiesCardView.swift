import SwiftUI

public struct EntitiesCardView: View {
    let config: EntitiesCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    public init(
        config: EntitiesCardConfig?,
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil
    ) {
        self.config = config
        self.entityStore = entityStore
        self.onMoreInfo = onMoreInfo
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header if title is present
            if let title = config?.title, !title.isEmpty {
                HStack(spacing: 8) {
                    if let icon = config?.icon {
                        Image(systemName: IconMapper.sfSymbol(for: icon))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            
            // Entity Rows
            if let rows = config?.entities, !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        let row = rows[index]
                        entityRowView(row: row)
                        
                        if index < rows.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
            }
        }
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
    
    @ViewBuilder
    private func entityRowView(row: EntityRowConfig) -> some View {
        if let entityId = row.entity, let entity = entityStore.entity(for: entityId) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: IconMapper.sfSymbol(
                    for: row.icon ?? entity.icon,
                    domain: entity.domain,
                    isActive: entity.isOn
                ))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor(entity: entity))
                .frame(width: 24)
                
                // Name
                Text(row.name ?? entity.friendlyName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Control or State Display
                if isToggleable(entity: entity) {
                    Toggle("", isOn: Binding(
                        get: { entity.isOn },
                        set: { _ in
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            Task {
                                await entityStore.toggle(entityId: entityId)
                            }
                        }
                    ))
                    .labelsHidden()
                } else {
                    Text(entity.displayState)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                onMoreInfo?(entityId)
            }
        } else if let name = row.name ?? row.entity {
            // Placeholder row
            HStack {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Unavailable")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
    
    private func isToggleable(entity: HAEntityState) -> Bool {
        let domain = entity.domain
        return domain == "light" || domain == "switch" || domain == "input_boolean" || domain == "automation"
    }
    
    private func iconColor(entity: HAEntityState) -> Color {
        guard entity.isOn else { return .secondary }
        switch entity.domain {
        case "light": return .haLightActive
        case "switch", "input_boolean": return .haSwitchActive
        default: return .haBlue
        }
    }
}
