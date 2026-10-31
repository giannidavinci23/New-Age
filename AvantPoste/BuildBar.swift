import SwiftUI

struct BuildBar: View {
    @Environment(Game.self) private var game
    @Binding var tool: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if tool != nil {
                    Button { tool = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 34)
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BuildingType.buildable) { type in
                        BuildCard(icon: type.icon, title: type.name, detail: type.cost.label,
                                  selected: tool == .build(type), enabled: game.canAfford(type.cost))
                            .onTapGesture { select(.build(type)) }
                    }
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1, height: 56)
                    BuildCard(icon: "🪓", title: "Défricher", detail: "+\(Int(Game.clearedForestWood)) 🪵",
                              selected: tool == .clear, enabled: true)
                        .onTapGesture { select(.clear) }
                    BuildCard(icon: "🧨", title: "Démolir", detail: "rend 50 %",
                              selected: tool == .demolish, enabled: true)
                        .onTapGesture { select(.demolish) }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.regularMaterial)
    }

    private func select(_ candidate: Tool) {
        tool = tool == candidate ? nil : candidate
    }

    private var caption: String {
        switch tool {
        case .build(let type)?: "\(type.icon) \(type.name) — \(type.summary)"
        case .clear?: "🪓 Touchez une forêt pour la couper (+\(Int(Game.clearedForestWood)) 🪵)."
        case .demolish?: "🧨 Touchez un bâtiment pour le démolir (50 % remboursés)."
        case nil: "Choisissez une construction, ou touchez un bâtiment pour le gérer."
        }
    }
}

struct BuildCard: View {
    let icon: String
    let title: String
    let detail: String
    let selected: Bool
    let enabled: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 28))
            Text(title)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 4)
        .frame(width: 78, height: 82)
        .background(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .opacity(enabled ? 1 : 0.45)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}
