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
                        HAIconView(icon: icon)
                            .frame(width: 18, height: 18)
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
                                .padding(.leading, 50)
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
                HAIconView(
                    icon: row.icon ?? entity.icon,
                    domain: entity.domain,
                    isActive: entity.isOn
                )
                .frame(width: 20, height: 20)
                .foregroundStyle(iconColor(entity: entity))
                
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
                } else if let options = entity.attributes["options"]?.arrayValue?.compactMap(\.stringValue) ?? entity.attributes["activity_list"]?.arrayValue?.compactMap(\.stringValue), !options.isEmpty {
                    let current = (entity.domain == "remote" ? entity.attributes["current_activity"]?.stringValue : nil) ?? entity.state
                    Menu {
                        ForEach(options, id: \.self) { opt in
                            Button {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                Task {
                                    if entity.domain == "remote" {
                                        await entityStore.selectRemoteActivity(entityId: entityId, activity: opt)
                                    } else {
                                        await entityStore.selectOption(entityId: entityId, option: opt)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(opt)
                                    if opt == current { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(current)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
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
