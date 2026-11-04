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

                let rows = stats(type)
                if !rows.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(rows) { stat in
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
                }

                if type == .port { PortTrade() }

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
        let workers = game.staff[index] ?? 0
        if type.maxWorkers > 0 {
            rows.append(Stat(label: "👷 Employés", value: "\(workers) / \(type.maxWorkers)"))
        }
        if let out = game.output(at: index) {
            rows.append(Stat(label: "\(out.resource.icon) Production", value: "+" + perSecond(out.perSecond)))
            if let input = out.input {
                rows.append(Stat(label: "\(input.icon) Consommation", value: "−" + perSecond(out.inputPerSecond)))
            }
        }
        if type.isProducer {
            var parts: [String] = []
            if game.hasWorkshopBoost(at: index) { parts.append("+\(percent(Game.workshopBonus)) atelier") }
            if game.forgeBonus > 0 { parts.append("+\(percent(game.forgeBonus)) forge") }
            rows.append(Stat(label: "⬆️ Bonus", value: parts.isEmpty ? "aucun" : parts.joined(separator: ", ")))
        }
        switch type {
        case .farm:
            let irrigation = game.count(.water, around: index) > 0 ? "+25 % (eau)"
                : game.count(.well, around: index) > 0 ? "+25 % (puits)" : "non"
            rows.append(Stat(label: "💧 Irrigation", value: irrigation))
            rows.append(Stat(label: "\(game.season.icon) Saison", value: "×" + game.season.farmMultiplier.formatted()))
        case .lumber, .hunter:
            rows.append(Stat(label: "🌲 Forêts voisines", value: "\(game.count(.forest, around: index))"))
        case .quarry:
            rows.append(Stat(label: "🪨 Roches voisines", value: "\(game.count(.rock, around: index))"))
        case .well:
            rows.append(Stat(label: "🌾 Fermes irriguées", value: "\(game.count(.farm, around: index))"))
        case .market:
            rows.append(Stat(label: "🪙 Recettes fiscales", value: workers > 0 ? "+40 %" : "fermé"))
        case .tavern:
            rows.append(Stat(label: "😊 Bonheur", value: workers > 0 ? "+8" : "fermée"))
        case .fountain:
            rows.append(Stat(label: "😊 Bonheur", value: "+4"))
        case .chapel:
            rows.append(Stat(label: "😊 Bonheur", value: "+5"))
            rows.append(Stat(label: "🚶 Départs en temps de crise", value: "÷ 2"))
        case .granary:
            rows.append(Stat(label: "🐀 Rats", value: "tenus à l'écart"))
        case .lighthouse:
            rows.append(Stat(label: "😊 Bonheur", value: "+15"))
        case .bakery, .smokehouse, .sawmill, .stonemason:
            rows.append(Stat(label: "🔧 Bâtiments améliorés", value: "\(game.improvedCount(by: index))"))
            rows.append(Stat(label: "⬆️ Bonus", value: workers > 0 ? "+\(percent(Game.workshopBonus))" : "à l'arrêt"))
        case .forge:
            rows.append(Stat(label: "⬆️ Toute la production", value: "+\(percent(game.forgeBonus))"))
        default:
            break
        }
        if type.housing > 0 { rows.append(Stat(label: "🛏️ Logements", value: "\(type.housing)")) }
        let storage = type.storage.entries
        if !storage.isEmpty {
            rows.append(Stat(label: "📦 Stockage",
                             value: storage.map { "+\(Int($0.amount)) \($0.resource.icon)" }.joined(separator: " ")))
        }
        if type.heating > 0 {
            rows.append(Stat(label: "🔥 Chauffage en hiver", value: "−" + type.heating.formatted() + " 🪵/s"))
        }
        return rows
    }

    private func perSecond(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(2))) + " /s"
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }

    private func note(_ type: BuildingType, tile: Tile) -> String? {
        switch type {
        case .camp:
            return "Touchez 👥 en haut de l'écran pour régler les impôts et suivre le bonheur."
        case .house:
            return "Pour l'agrandir, choisissez le manoir 🏡 dans Village puis touchez cette maison : 8 logements au lieu de 4."
        default:
            break
        }
        guard type.maxWorkers > 0, !tile.paused else { return nil }
        if (game.staff[index] ?? 0) < type.maxWorkers {
            return "Il manque des bras : les colons travaillent d'abord à la nourriture, puis au bois, puis à la pierre."
        }
        if type == .carpenter, game.stock.wood <= Game.carpenterReserve {
            return "Le menuisier garde \(Int(Game.carpenterReserve)) 🪵 pour le chauffage : il attend que le stock remonte."
        }
        if let workshop = type.workshop, !game.hasWorkshopBoost(at: index) {
            return "Astuce : \(workshop.icon) \(workshop.name.lowercased()) à 2 cases ou moins → +50 % de production (onglet Ateliers)."
        }
        if !type.improves.isEmpty, game.improvedCount(by: index) == 0 {
            return "Plus rien à améliorer à 2 cases ou moins : construisez à côté, ou déplacez cet atelier."
        }
        return nil
    }
}

/// Where a resource comes from and where it goes, opened from the resource bar.
struct ResourceSheet: View {
    @Environment(Game.self) private var game
    let resource: Resource

    var body: some View {
        let lines = game.rateBreakdown(for: resource)
        let made = lines.filter { $0.amount >= 0 }
        let used = lines.filter { $0.amount < 0 }
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("En réserve")
                        Spacer()
                        Text(reserve)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bilan")
                        Spacer()
                        Text(signed(game.rates[resource]))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(color(game.rates[resource]))
                    }
                }
                Section {
                    if made.isEmpty {
                        Text("Rien ne produit encore cette ressource.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(made) { row($0) }
                } header: {
                    Text("Production")
                } footer: {
                    Text(tip)
                }
                if !used.isEmpty {
                    Section("Consommation") {
                        ForEach(used) { row($0) }
                    }
                }
            }
            .navigationTitle("\(resource.icon) \(resource.name)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var reserve: String {
        let amount = Int(game.stock[resource])
        return resource == .gold ? "\(amount)" : "\(amount) / \(Int(game.storageCap[resource]))"
    }

    private var tip: String {
        switch resource {
        case .food: "Une boulangerie près des fermes, un fumoir près des pêcheries et des chasseurs : +50 %. La forge ajoute 15 % à tout."
        case .wood: "Une scierie à 2 cases ou moins des bûcherons : +50 %. La forge ajoute 15 % à tout."
        case .stone: "Une marbrerie à 2 cases ou moins des carrières : +50 %. La forge ajoute 15 % à tout."
        case .gold: "Chaque marché tenu augmente les impôts de 40 %. Le menuisier et le port changent vos surplus en or."
        }
    }

    private func row(_ line: RateLine) -> some View {
        HStack {
            Text(line.label)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(signed(line.amount))
                    .monospacedDigit()
                    .foregroundStyle(color(line.amount))
                if line.bonus >= 0.005 {
                    Text("dont bonus " + signed(line.bonus))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func signed(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())) + " /s"
    }

    private func color(_ amount: Double) -> Color {
        amount >= 0.005 ? .green : amount <= -0.005 ? .red : .secondary
    }
}

private struct PortTrade: View {
    @Environment(Game.self) private var game
    @State private var deals = 0

    var body: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                Text("Lots de \(Int(Game.tradeLot))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Vendre")
                Text("Acheter")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach([Resource.food, .wood, .stone]) { resource in
                let sell = game.tradePrice(resource, buying: false)
                let buy = game.tradePrice(resource, buying: true)
                GridRow {
                    Text("\(resource.icon) \(Int(game.stock[resource]))")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("+\(Int(sell)) 🪙") { trade(resource, buying: false) }
                        .disabled(game.stock[resource] < Game.tradeLot)
                    Button("−\(Int(buy)) 🪙") { trade(resource, buying: true) }
                        .disabled(game.stock.gold < buy)
                }
            }
        }
        .font(.callout)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .sensoryFeedback(.success, trigger: deals)
    }

    private func trade(_ resource: Resource, buying: Bool) {
        if let error = game.trade(resource, buying: buying) {
            game.notify(error, .bad)
        } else {
            deals += 1
        }
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
                    Text("Bonheur : \(Int(game.happiness.rounded())) % (tend vers \(Int(game.happinessTarget)) %)")
                } footer: {
                    Text("Au-dessus de 40 %, de nouveaux colons arrivent tant qu'il reste des logements. La famine, le froid ou un bonheur sous 25 % les font partir.")
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
                        "Les fermes s'arrêtent, la pêche ralentit et chaque maison brûle du bois. Faites des réserves en automne ; le chasseur, lui, travaille toute l'année.")
                    tip("👷", "Les colons",
                        "Chacun mange 0,1 🍞/s et travaille là où il manque des bras, la nourriture d'abord. Mettez un bâtiment en pause pour libérer ses employés.")
                    tip("😊", "Le bonheur",
                        "Au-dessus de 40 %, de nouveaux colons arrivent s'il reste des logements. Famine, froid ou bonheur sous 25 % les font fuir.")
                    tip("🗺️", "L'emplacement compte",
                        "Bûcheron et chasseur profitent des forêts voisines, la carrière des roches voisines. La ferme gagne +25 % près de l'eau ou d'un puits.")
                    tip("🏡", "Agrandir",
                        "Un manoir (onglet Village) peut remplacer une maison : 8 colons au lieu de 4, sur la même case.")
                    tip("⚓", "Le port",
                        "Touchez-le pour vendre vos surplus ou acheter ce qui manque, à tout moment.")
                    tip("⚙️", "Les ateliers",
                        "Boulangerie, fumoir, scierie et marbrerie ajoutent 50 % aux bâtiments de production à 2 cases ou moins ; une flèche verte les signale. La forge ajoute 15 % partout.")
                    tip("📊", "Les détails",
                        "Touchez une ressource en haut de l'écran pour voir ce qui la produit et ce qui la consomme.")
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
