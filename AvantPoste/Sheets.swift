import SwiftUI

private struct Stat: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct BuildingSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss
    let index: Int

    var body: some View {
        let tile = game.tiles[index]
        if let type = tile.building {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Text(type.icon)
                        .font(.system(size: 52))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.name)
                            .font(.title2.weight(.bold))
                        Text(type.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(stats(type)) { stat in
                        HStack {
                            Text(stat.label)
                            Spacer()
                            Text(stat.value)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                }
                .font(.callout)
                .padding(14)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                if let note = note(type, tile: tile) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if type.maxWorkers > 0 {
                        Button { game.togglePause(at: index) } label: {
                            Label(tile.paused ? "Reprendre" : "Mettre en pause",
                                  systemImage: tile.paused ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                    if type != .camp && type != .lighthouse {
                        Button(role: .destructive) {
                            if let error = game.demolish(at: index) { game.notify(error, .bad) }
                            dismiss()
                        } label: {
                            Label("Démolir", systemImage: "hammer.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(22)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func stats(_ type: BuildingType) -> [Stat] {
        var rows: [Stat] = []
        if type.maxWorkers > 0 {
            rows.append(Stat(label: "👷 Employés", value: "\(game.staff[index] ?? 0) / \(type.maxWorkers)"))
        }
        if let out = game.output(at: index) {
            let amount = out.perSecond.formatted(.number.precision(.fractionLength(2)))
            rows.append(Stat(label: "\(out.resource.icon) Production", value: "+\(amount) /s"))
        }
        switch type {
        case .farm:
            rows.append(Stat(label: "💧 Près de l'eau", value: game.count(.water, around: index) > 0 ? "+25 %" : "non"))
            rows.append(Stat(label: "\(game.season.icon) Saison", value: "×" + game.season.farmMultiplier.formatted()))
        case .lumber:
            rows.append(Stat(label: "🌲 Forêts voisines", value: "\(game.count(.forest, around: index))"))
        case .quarry:
            rows.append(Stat(label: "🪨 Roches voisines", value: "\(game.count(.rock, around: index))"))
        default:
            break
        }
        if type.housing > 0 { rows.append(Stat(label: "🛏️ Logements", value: "\(type.housing)")) }
        if type.storage > 0 { rows.append(Stat(label: "📦 Stockage", value: "+\(Int(type.storage))")) }
        if type.heating > 0 {
            rows.append(Stat(label: "🔥 Chauffage en hiver", value: "−" + type.heating.formatted() + " 🪵/s"))
        }
        return rows
    }

    private func note(_ type: BuildingType, tile: Tile) -> String? {
        if type == .camp { return "Touchez 👥 en haut de l'écran pour régler les impôts et suivre le bonheur." }
        guard type.maxWorkers > 0, !tile.paused else { return nil }
        if (game.staff[index] ?? 0) < type.maxWorkers {
            return "Il manque des bras : les colons travaillent d'abord à la nourriture, puis au bois, puis à la pierre."
        }
        return nil
    }
}

struct ColonySheet: View {
    @Environment(Game.self) private var game

    var body: some View {
        @Bindable var game = game
        NavigationStack {
            List {
                Section("Population") {
                    row("👥 Habitants", "\(game.population)")
                    row("🏠 Logements", "\(game.housing)")
                    row("👷 Au travail", "\(game.population - game.idle)")
                    row("💤 Sans emploi", "\(game.idle)")
                    row("🍞 Consommation", game.foodConsumption.formatted(.number.precision(.fractionLength(1))) + " /s")
                }

                Section {
                    Picker("Impôts", selection: $game.taxLevel) {
                        ForEach(TaxLevel.allCases) { level in
                            Text(level.name).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    row("🪙 Recettes", "+" + game.rates.gold.formatted(.number.precision(.fractionLength(2))) + " /s")
                } header: {
                    Text("Impôts")
                } footer: {
                    Text("Des impôts bas rendent les colons heureux (+10), des impôts élevés les fâchent (−15).")
                }

                Section {
                    ForEach(game.happinessFactors) { factor in
                        HStack {
                            Text(factor.label)
                            Spacer()
                            Text(factor.value > 0 ? "+\(factor.value)" : "\(factor.value)")
                                .monospacedDigit()
                                .foregroundStyle(factor.value >= 0 ? Color.green : Color.red)
                        }
                    }
                } header: {
                    Text("Bonheur : \(Int(game.happiness.rounded())) % (tend vers \(Int(game.happinessTarget)) %)")
                } footer: {
                    Text("Au-dessus de 40 %, de nouveaux colons arrivent tant qu'il reste des logements. La famine, le froid ou un bonheur sous 25 % les font partir.")
                }
            }
            .navigationTitle("Colonie")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct ObjectivesSheet: View {
    @Environment(Game.self) private var game

    var body: some View {
        NavigationStack {
            List(Objective.allCases) { objective in
                let done = objective.rawValue < game.objectiveIndex
                let current = objective.rawValue == game.objectiveIndex
                HStack(spacing: 12) {
                    Image(systemName: done ? "checkmark.circle.fill" : current ? "target" : "circle")
                        .font(.title3)
                        .foregroundStyle(done ? Color.green : current ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(objective.title)
                            .fontWeight(current ? .bold : .regular)
                            .strikethrough(done)
                        Text(objective == .lighthouse ? "Victoire !" : "Récompense : \(objective.reward.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(done ? 0.6 : 1)
            }
            .navigationTitle("Objectifs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tip("🎯", "Votre but",
                        "Faire grandir l'avant-poste jusqu'à bâtir le Grand Phare 🗼 au bord de l'eau (30 habitants requis).")
                    tip("⏱️", "Temps réel",
                        "Le temps s'écoule en continu, quatre saisons par an. Mettez en pause ou accélérez avec les boutons en haut.")
                    tip("❄️", "L'hiver",
                        "Les fermes s'arrêtent, la pêche ralentit et chaque maison brûle du bois. Faites des réserves en automne !")
                    tip("👷", "Les colons",
                        "Chacun mange 0,1 🍞/s et travaille là où il manque des bras, la nourriture d'abord. Mettez un bâtiment en pause pour libérer ses employés.")
                    tip("😊", "Le bonheur",
                        "Au-dessus de 40 %, de nouveaux colons arrivent s'il reste des logements. Famine, froid ou bonheur sous 25 % les font fuir.")
                    tip("🗺️", "L'emplacement compte",
                        "Le bûcheron produit selon les forêts voisines, la carrière selon les roches voisines, la ferme gagne +25 % près de l'eau.")
                    tip("🪓", "Défricher",
                        "Couper une forêt rapporte du bois tout de suite. Les forêts repoussent doucement au printemps et en été.")
                    tip("🧳", "Les imprévus",
                        "Caravanes, marchands, tempêtes ou rats : gardez un œil sur les messages !")
                }
                .padding(20)
            }
            .navigationTitle("Comment jouer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("C'est parti") { dismiss() }
                }
            }
        }
    }

    private func tip(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
