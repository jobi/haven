import SwiftUI

public struct EntityMoreInfoSheet: View {
    let entity: HAEntityState
    let entityStore: EntityStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var localBrightness: Double = 50.0
    
    public init(entity: HAEntityState, entityStore: EntityStore) {
        self.entity = entity
        self.entityStore = entityStore
        self._localBrightness = State(initialValue: entity.brightnessPercentage ?? 50.0)
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Header State Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: IconMapper.sfSymbol(
                            for: entity.icon,
                            domain: entity.domain,
                            isActive: entity.isOn
                        ))
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(iconColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entity.friendlyName)
                                .font(.headline)
                            Text(entity.entityId)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(entity.displayState)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Quick Controls Section
                Section("Controls") {
                    if isToggleable {
                        Toggle("Power", isOn: Binding(
                            get: { entity.isOn },
                            set: { _ in
                                Task {
                                    await entityStore.toggle(entityId: entity.entityId)
                                }
                            }
                        ))
                    }
                    
                    if entity.domain == "light" && entity.isOn {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Brightness")
                                Spacer()
                                Text("\(Int(localBrightness))%")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $localBrightness, in: 1...100, step: 1) {
                                Text("Brightness")
                            } onEditingChanged: { isEditing in
                                if !isEditing {
                                    Task {
                                        await entityStore.setBrightness(entityId: entity.entityId, percentage: localBrightness)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Attributes Section
                if !entity.attributes.isEmpty {
                    Section("Attributes") {
                        ForEach(Array(entity.attributes.keys.sorted()), id: \.self) { key in
                            if let val = entity.attributes[key] {
                                HStack {
                                    Text(key)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(displayValue(for: val))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Entity Info")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isToggleable: Bool {
        let domain = entity.domain
        return domain == "light" || domain == "switch" || domain == "input_boolean" || domain == "automation"
    }
    
    private var iconColor: Color {
        guard entity.isOn else { return .secondary }
        switch entity.domain {
        case "light": return .haLightActive
        case "switch", "input_boolean": return .haSwitchActive
        default: return .haBlue
        }
    }
    
    private func displayValue(for codable: AnyCodable) -> String {
        if let s = codable.stringValue { return s }
        if let i = codable.intValue { return "\(i)" }
        if let d = codable.doubleValue { return String(format: "%.2f", d) }
        if let b = codable.boolValue { return b ? "true" : "false" }
        if let arr = codable.arrayValue { return "[\(arr.count) items]" }
        if let dict = codable.dictionaryValue { return "{\(dict.count) keys}" }
        return "-"
    }
}
