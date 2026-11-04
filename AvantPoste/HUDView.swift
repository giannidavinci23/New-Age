import SwiftUI

struct HUDView: View {
    @Environment(Game.self) private var game
    @Binding var showColony: Bool
    @Binding var showObjectives: Bool
    @Binding var showHelp: Bool
    @Binding var confirmNewGame: Bool
    @Binding var detailResource: Resource?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(game.season.icon) \(game.season.name) · An \(game.year)")
                        .font(.subheadline.weight(.bold))
                    ProgressView(value: game.seasonProgress)
                        .tint(seasonTint)
                        .frame(width: 120)
                }
                Spacer(minLength: 0)
                SpeedControl()
                Menu {
                    Button { showHelp = true } label: {
                        Label("Comment jouer", systemImage: "questionmark.circle")
                    }
                    Button(role: .destructive) { confirmNewGame = true } label: {
                        Label("Nouvelle colonie", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                }
            }

            HStack(spacing: 6) {
                ForEach(Resource.allCases) { resource in
                    Button { detailResource = resource } label: {
                        ResourceChip(
                            resource: resource,
                            amount: game.stock[resource],
                            rate: game.rates[resource],
                            full: resource != .gold && game.stock[resource] >= game.storageCap[resource] - 0.5
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button { showColony = true } label: {
                    HStack(spacing: 10) {
                        Text("👥 \(game.population)/\(game.housing)")
                        Text("\(moodIcon) \(Int(game.happiness.rounded())) %")
                    }
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .pill()
                }
                Button { showObjectives = true } label: {
                    Text("🎯 \(game.currentObjective?.title ?? "Tous les objectifs sont remplis")")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pill()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var moodIcon: String {
        switch game.happiness {
        case 70...: "😄"
        case 40..<70: "🙂"
        case 25..<40: "😐"
        default: "😠"
        }
    }

    private var seasonTint: Color {
        switch game.season {
        case .spring: .green
        case .summer: .yellow
        case .autumn: .orange
        case .winter: .cyan
        }
    }
}

struct ResourceChip: View {
    let resource: Resource
    let amount: Double
    let rate: Double
    let full: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text(resource.icon)
                    .font(.callout)
                Text("\(Int(amount))")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(full ? Color.orange : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(rateLabel)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(rateColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var rateLabel: String {
        if full && rate > 0 { return "plein" }
        guard abs(rate) >= 0.05 else { return "—" }
        return rate.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + "/s"
    }

    private var rateColor: Color {
        if full && rate > 0 { return .orange }
        if rate >= 0.05 { return .green }
        if rate <= -0.05 { return .red }
        return .secondary
    }
}

struct SpeedControl: View {
    @Environment(Game.self) private var game
    private let speeds = [0, 1, 2, 4]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(speeds, id: \.self) { speed in
                let selected = game.speed == speed
                Button {
                    game.speed = speed
                } label: {
                    Group {
                        if speed == 0 {
                            Image(systemName: "pause.fill")
                        } else {
                            Text("\(speed)×")
                        }
                    }
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 28)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? (speed == 0 ? Color.orange : Color.accentColor) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
    }
}

extension View {
    func pill() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.07), in: Capsule())
    }
}
