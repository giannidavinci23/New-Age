import Foundation
import Observation

@Observable
final class Game {
    static let cols = 14
    static let rows = 18
    static let seasonLength = 45.0
    static let foodPerColonist = 0.1
    static let offerDuration = 20.0
    static let lighthousePopulation = 30
    static let clearedForestWood = 8.0

    // MARK: Saved state

    var tiles: [Tile] = []
    var stock = Stock()
    var elapsed = 0.0
    var population = 6
    var happiness = 60.0
    var taxLevel: TaxLevel = .normal
    var status: GameStatus = .playing
    var objectiveIndex = 0
    var offer: TradeOffer?
    var hasWon = false

    // MARK: Session state

    /// 0 = paused, otherwise game seconds per real second.
    var speed = 1
    var toasts: [Toast] = []
    private(set) var season: Season = .spring
    private(set) var year = 1
    /// Workers per workplace, keyed by tile index.
    private(set) var staff: [Int: Int] = [:]
    private(set) var idle = 0
    /// Net change per second, after consumption.
    private(set) var rates = Stock()
    private(set) var happinessTarget = 60.0
    private(set) var happinessFactors: [HappinessFactor] = []
    private(set) var famine = false
    private(set) var cold = false

    @ObservationIgnored private var seed: UInt64 = 0
    @ObservationIgnored private var rng = SplitMix64(seed: 0)
    @ObservationIgnored private var growthProgress = 0.0
    @ObservationIgnored private var leaveProgress = 0.0
    @ObservationIgnored private var nextEventAt = 50.0
    @ObservationIgnored private var nextRegrowthAt = 20.0
    @ObservationIgnored private var staffDirty = true
    @ObservationIgnored private var lastSave = Date()

    init() {
        if !load() { newGame() }
    }

    func newGame(seed: UInt64 = .random(in: 1...UInt64.max)) {
        self.seed = seed
        rng = SplitMix64(seed: seed &* 31 &+ 7)
        tiles = MapGenerator.generate(seed: seed)
        stock = Stock(food: 40, wood: 60, stone: 10, gold: 20)
        elapsed = 0
        season = .spring
        year = 1
        population = 6
        happiness = 60
        taxLevel = .normal
        speed = 1
        status = .playing
        objectiveIndex = 0
        offer = nil
        hasWon = false
        growthProgress = 0
        leaveProgress = 0
        nextEventAt = 50
        nextRegrowthAt = 20
        toasts = []
        recomputeStaffing()
        updateEconomy()
        notify("Bienvenue ! Construisez une ferme 🌾 pour nourrir vos colons.")
        save()
    }

    // MARK: Simulation

    func advance(_ realSeconds: Double) {
        // Saved even while paused, so buildings placed during a pause survive the app being killed.
        if Date().timeIntervalSince(lastSave) > 5 { save() }
        guard status == .playing, speed > 0 else { return }
        let realDt = min(realSeconds, 0.5)
        let dt = realDt * Double(speed)
        elapsed += dt
        updateCalendar()
        if staffDirty { recomputeStaffing() }
        updateEconomy()
        applyProduction(dt)
        updatePopulation(dt)
        if var deal = offer {
            deal.remaining -= realDt
            if deal.remaining > 0 {
                offer = deal
            } else {
                offer = nil
                notify("🧳 Le marchand a repris la route.")
            }
        }
        if elapsed >= nextEventAt { triggerEvent() }
        if elapsed >= nextRegrowthAt { regrowForest() }
        checkObjectives()
    }

    var seasonProgress: Double {
        elapsed.truncatingRemainder(dividingBy: Game.seasonLength) / Game.seasonLength
    }

    private func updateCalendar(announce: Bool = true) {
        let n = Int(elapsed / Game.seasonLength)
        let newSeason = Season(rawValue: n % 4) ?? .spring
        let newYear = n / 4 + 1
        guard newSeason != season || newYear != year else { return }
        season = newSeason
        year = newYear
        if announce { notify(newSeason.announcement, newSeason == .winter ? .bad : .info) }
    }

    private func recomputeStaffing() {
        staffDirty = false
        var available = population
        var newStaff: [Int: Int] = [:]
        let workplaces = tiles.indices
            .filter { (tiles[$0].building?.maxWorkers ?? 0) > 0 }
            .sorted { a, b in
                let pa = tiles[a].building!.priority, pb = tiles[b].building!.priority
                return pa != pb ? pa < pb : a < b
            }
        for i in workplaces {
            guard !tiles[i].paused else {
                newStaff[i] = 0
                continue
            }
            let workers = min(tiles[i].building!.maxWorkers, available)
            newStaff[i] = workers
            available -= workers
        }
        if newStaff != staff { staff = newStaff }
        if available != idle { idle = available }
    }

    /// Recomputes rates, shortages and happiness without advancing time.
    private func updateEconomy() {
        var produced = Stock()
        var markets = 0.0, taverns = 0, fountains = 0, heating = 0.0
        var lighthouse = false
        for i in tiles.indices {
            guard let building = tiles[i].building else { continue }
            if let out = output(at: i) { produced[out.resource] += out.perSecond }
            switch building {
            case .market: markets += Double(staff[i] ?? 0)
            case .tavern where (staff[i] ?? 0) > 0: taverns += 1
            case .fountain: fountains += 1
            case .lighthouse: lighthouse = true
            default: break
            }
            if season == .winter { heating += building.heating }
        }
        produced.gold = Double(population) * taxLevel.goldPerColonist * (1 + 0.4 * markets)

        var net = produced
        net.food -= foodConsumption
        net.wood -= heating
        if net != rates { rates = net }

        let nowFamine = stock.food < 0.5 && net.food < 0
        if nowFamine != famine {
            famine = nowFamine
            if nowFamine { notify("⚠️ Famine ! Les colons quittent l'avant-poste.", .bad) }
        }
        let nowCold = season == .winter && heating > 0 && stock.wood < 0.5 && net.wood < 0
        if nowCold != cold {
            cold = nowCold
            if nowCold { notify("🥶 Plus de bois pour se chauffer !", .bad) }
        }

        var factors = [HappinessFactor(label: "Moral de base", value: 50)]
        if famine {
            factors.append(.init(label: "Famine", value: -40))
        } else if stock.food >= 30 {
            factors.append(.init(label: "Greniers bien remplis", value: 10))
        }
        if cold { factors.append(.init(label: "Froid", value: -30)) }
        if taxLevel.happiness != 0 { factors.append(.init(label: taxLevel.factorLabel, value: taxLevel.happiness)) }
        if taverns > 0 { factors.append(.init(label: "Tavernes", value: min(taverns, 3) * 8)) }
        if fountains > 0 { factors.append(.init(label: "Fontaines", value: min(fountains, 4) * 4)) }
        if lighthouse { factors.append(.init(label: "Fierté du Grand Phare", value: 15)) }
        if population >= 8, Double(idle) > Double(population) * 0.4 {
            factors.append(.init(label: "Chômage", value: -10))
        }
        if population > housing { factors.append(.init(label: "Surpopulation", value: -15)) }
        if factors != happinessFactors { happinessFactors = factors }
        let target = Double(min(100, max(0, factors.reduce(0) { $0 + $1.value })))
        if target != happinessTarget { happinessTarget = target }
    }

    private func applyProduction(_ dt: Double) {
        let cap = storageCap
        var next = stock
        for resource in Resource.allCases {
            let value = max(0, next[resource] + rates[resource] * dt)
            next[resource] = resource == .gold ? value : min(value, cap)
        }
        stock = next
    }

    private func updatePopulation(_ dt: Double) {
        happiness += (happinessTarget - happiness) * min(1, dt * 0.2)

        if housing > population, !famine, !cold, stock.food >= 1, happiness >= 40 {
            growthProgress += dt * (0.03 + (happiness - 40) / 60 * 0.12)
            if growthProgress >= 1 {
                growthProgress = 0
                population += 1
                staffDirty = true
            }
        }

        var leaveRate = 0.0
        if famine { leaveRate += 0.25 }
        if cold { leaveRate += 0.12 }
        if happiness < 25 { leaveRate += 0.08 }
        if population > housing { leaveRate += 0.3 }
        guard leaveRate > 0 else {
            leaveProgress = 0
            return
        }
        leaveProgress += dt * leaveRate
        guard leaveProgress >= 1 else { return }
        leaveProgress = 0
        population -= 1
        staffDirty = true
        if population <= 0 {
            population = 0
            status = .lost
            save()
        }
    }

    // MARK: Queries

    static func index(_ x: Int, _ y: Int) -> Int { y * cols + x }

    static func coords(_ i: Int) -> (x: Int, y: Int) { (i % cols, i / cols) }

    static func neighbors(of i: Int) -> [Int] {
        let (x, y) = coords(i)
        var result: [Int] = []
        for dy in -1...1 {
            for dx in -1...1 where dx != 0 || dy != 0 {
                let nx = x + dx, ny = y + dy
                if nx >= 0, ny >= 0, nx < cols, ny < rows { result.append(index(nx, ny)) }
            }
        }
        return result
    }

    func count(_ terrain: Terrain, around i: Int) -> Int {
        Game.neighbors(of: i).reduce(0) { $0 + (tiles[$1].terrain == terrain ? 1 : 0) }
    }

    var housing: Int { tiles.reduce(0) { $0 + ($1.building?.housing ?? 0) } }

    var storageCap: Double { tiles.reduce(0) { $0 + ($1.building?.storage ?? 0) } }

    var foodConsumption: Double { Double(population) * Game.foodPerColonist }

    var currentObjective: Objective? { Objective(rawValue: objectiveIndex) }

    func has(_ type: BuildingType) -> Bool { tiles.contains { $0.building == type } }

    func canAfford(_ cost: Stock) -> Bool {
        cost.entries.allSatisfy { stock[$0.resource] >= $0.amount }
    }

    /// What the building on tile `i` produces per second with its current staff and season.
    func output(at i: Int) -> BuildingOutput? {
        guard let building = tiles[i].building, building.maxWorkers > 0 else { return nil }
        let staffed = Double(staff[i] ?? 0) / Double(building.maxWorkers)
        switch building {
        case .farm:
            let water = count(.water, around: i) > 0 ? 1.25 : 1
            return BuildingOutput(resource: .food, perSecond: staffed * season.farmMultiplier * water)
        case .fishery:
            return BuildingOutput(resource: .food, perSecond: 0.5 * staffed * (season == .winter ? 0.5 : 1))
        case .lumber:
            return BuildingOutput(resource: .wood, perSecond: 0.16 * Double(count(.forest, around: i)) * staffed)
        case .quarry:
            return BuildingOutput(resource: .stone, perSecond: 0.14 * Double(count(.rock, around: i)) * staffed)
        default:
            return nil
        }
    }

    /// Why `type` can't go on tile `i`, or nil when it can.
    func placementError(_ type: BuildingType, at i: Int, checkCost: Bool = true) -> String? {
        let tile = tiles[i]
        if tile.building != nil { return "Cette case est déjà occupée." }
        if tile.terrain != .grass { return "Il faut construire sur une prairie." }
        switch type {
        case .lumber where count(.forest, around: i) == 0:
            return "Le bûcheron doit toucher une forêt."
        case .quarry where count(.rock, around: i) == 0:
            return "La carrière doit toucher des roches."
        case .fishery where count(.water, around: i) == 0:
            return "La pêcherie doit être au bord de l'eau."
        case .lighthouse:
            if has(.lighthouse) { return "Il n'y a qu'un seul Grand Phare." }
            if count(.water, around: i) == 0 { return "Le Grand Phare doit être au bord de l'eau." }
        default:
            break
        }
        guard checkCost else { return nil }
        if type == .lighthouse && population < Game.lighthousePopulation {
            return "Il faut au moins \(Game.lighthousePopulation) habitants."
        }
        for entry in type.cost.entries where stock[entry.resource] < entry.amount {
            return "Pas assez \(entry.resource.partitive) \(entry.resource.icon)."
        }
        return nil
    }

    // MARK: Player actions

    func build(_ type: BuildingType, at i: Int) -> String? {
        if let error = placementError(type, at: i) { return error }
        for entry in type.cost.entries { stock[entry.resource] -= entry.amount }
        tiles[i].building = type
        tiles[i].paused = false
        recomputeStaffing()
        updateEconomy()
        if type == .lighthouse { win() }
        return nil
    }

    func demolish(at i: Int) -> String? {
        guard let building = tiles[i].building else { return "Il n'y a rien à démolir ici." }
        if building == .camp { return "Le campement ne peut pas être démoli." }
        if building == .lighthouse { return "Le Grand Phare est éternel." }
        for entry in building.cost.entries { stock[entry.resource] += (entry.amount / 2).rounded(.down) }
        tiles[i].building = nil
        tiles[i].paused = false
        recomputeStaffing()
        updateEconomy()
        return nil
    }

    func clearForest(at i: Int) -> String? {
        guard tiles[i].terrain == .forest else { return "Seules les forêts peuvent être défrichées." }
        tiles[i].terrain = .grass
        stock.wood = min(stock.wood + Game.clearedForestWood, storageCap)
        updateEconomy()
        return nil
    }

    func togglePause(at i: Int) {
        tiles[i].paused.toggle()
        recomputeStaffing()
        updateEconomy()
    }

    func resolveOffer(accept: Bool) {
        guard let deal = offer else { return }
        offer = nil
        guard accept else { return }
        guard canAfford(deal.give) else {
            notify("Vous n'avez plus de quoi payer le marchand.", .bad)
            return
        }
        for entry in deal.give.entries { stock[entry.resource] -= entry.amount }
        for entry in deal.receive.entries { stock[entry.resource] += entry.amount }
        notify("🤝 Marché conclu !", .good)
    }

    func continueAfterWin() {
        status = .playing
    }

    func notify(_ text: String, _ kind: Toast.Kind = .info) {
        let toast = Toast(text: text, kind: kind)
        toasts.append(toast)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.toasts.removeAll { $0.id == toast.id }
        }
    }

    // MARK: Events

    private func triggerEvent() {
        nextEventAt = elapsed + Double.random(in: 40...75, using: &rng)
        let free = housing - population
        var events: [() -> Void] = []

        events.append { [self] in
            if free > 0 {
                let arrivals = min(3, free)
                population += arrivals
                staffDirty = true
                notify(arrivals > 1
                       ? "🐎 Une caravane arrive : \(arrivals) colons s'installent !"
                       : "🐎 Une caravane arrive : un colon s'installe !", .good)
            } else {
                notify("🐎 Une caravane passe… mais aucune maison n'est libre.")
            }
        }
        if season != .winter, has(.farm) {
            events.append { [self] in
                stock.food += 25
                notify("🌾 Récolte exceptionnelle : +25 🍞", .good)
            }
        }
        if stock.food > 40 {
            events.append { [self] in
                let lost = (stock.food * 0.2).rounded()
                stock.food -= lost
                notify("🐀 Des rats dans les greniers : -\(Int(lost)) 🍞", .bad)
            }
        }
        if has(.quarry) {
            events.append { [self] in
                stock.stone += 20
                notify("💎 Un filon découvert à la carrière : +20 🪨", .good)
            }
        }
        if season == .autumn || season == .winter, stock.wood > 20 {
            events.append { [self] in
                stock.wood -= 15
                notify("🌪️ Une tempête abîme les réserves : -15 🪵", .bad)
            }
        }
        if population >= 8 {
            events.append { [self] in
                happiness = min(100, happiness + 12)
                notify("🎉 Fête au village ! Le moral remonte.", .good)
            }
        }
        if offer == nil, let deal = makeOffer() {
            // Merchants are the most common visitors.
            events.append { [self] in offer = deal }
            events.append { [self] in offer = deal }
        }
        events.randomElement(using: &rng)?()
    }

    private func makeOffer() -> TradeOffer? {
        let deals: [(give: Stock, receive: Stock)] = [
            (Stock(wood: 30), Stock(gold: 25)),
            (Stock(gold: 20), Stock(food: 40)),
            (Stock(food: 40), Stock(stone: 25)),
            (Stock(gold: 30), Stock(stone: 40)),
            (Stock(stone: 20), Stock(gold: 30)),
        ]
        guard let deal = deals.filter({ canAfford($0.give) }).randomElement(using: &rng) else { return nil }
        return TradeOffer(give: deal.give, receive: deal.receive, remaining: Game.offerDuration)
    }

    /// Forests slowly spread onto empty meadows in spring and summer.
    private func regrowForest() {
        nextRegrowthAt = elapsed + 12
        guard season == .spring || season == .summer else { return }
        let candidates = tiles.indices.filter {
            tiles[$0].terrain == .grass && tiles[$0].building == nil && count(.forest, around: $0) >= 3
        }
        guard let i = candidates.randomElement(using: &rng) else { return }
        tiles[i].terrain = .forest
        updateEconomy()
    }

    private func isDone(_ objective: Objective) -> Bool {
        switch objective {
        case .farm: has(.farm)
        case .lumber: has(.lumber)
        case .pop10: population >= 10
        case .winter: year >= 2
        case .quarry: has(.quarry)
        case .tavern: has(.tavern)
        case .pop25: population >= 25
        case .lighthouse: has(.lighthouse)
        }
    }

    private func checkObjectives() {
        guard let objective = currentObjective, isDone(objective) else { return }
        objectiveIndex += 1
        for entry in objective.reward.entries { stock[entry.resource] += entry.amount }
        if objective != .lighthouse {
            let reward = objective.reward.entries.isEmpty ? "" : " (+\(objective.reward.label))"
            notify("🎯 \(objective.title) : réussi !\(reward)", .good)
        }
    }

    private func win() {
        guard !hasWon else { return }
        hasWon = true
        status = .won
        save()
    }

    // MARK: Persistence

    private struct SaveData: Codable {
        var seed: UInt64
        var rng: SplitMix64
        var tiles: [Tile]
        var stock: Stock
        var elapsed: Double
        var population: Int
        var happiness: Double
        var taxLevel: TaxLevel
        var status: GameStatus
        var objectiveIndex: Int
        var offer: TradeOffer?
        var hasWon: Bool
        var growthProgress: Double
        var leaveProgress: Double
        var nextEventAt: Double
        var nextRegrowthAt: Double
    }

    private static let saveURL = URL.documentsDirectory.appending(path: "avant-poste.json")

    func save() {
        lastSave = Date()
        let data = SaveData(
            seed: seed, rng: rng, tiles: tiles, stock: stock, elapsed: elapsed,
            population: population, happiness: happiness, taxLevel: taxLevel, status: status,
            objectiveIndex: objectiveIndex, offer: offer, hasWon: hasWon,
            growthProgress: growthProgress, leaveProgress: leaveProgress,
            nextEventAt: nextEventAt, nextRegrowthAt: nextRegrowthAt
        )
        do {
            try JSONEncoder().encode(data).write(to: Game.saveURL, options: .atomic)
        } catch {
            print("Sauvegarde impossible : \(error)")
        }
    }

    private func load() -> Bool {
        guard let raw = try? Data(contentsOf: Game.saveURL),
              let data = try? JSONDecoder().decode(SaveData.self, from: raw),
              data.tiles.count == Game.cols * Game.rows
        else { return false }
        seed = data.seed
        rng = data.rng
        tiles = data.tiles
        stock = data.stock
        elapsed = data.elapsed
        population = data.population
        happiness = data.happiness
        taxLevel = data.taxLevel
        status = data.status
        objectiveIndex = data.objectiveIndex
        offer = data.offer
        hasWon = data.hasWon
        growthProgress = data.growthProgress
        leaveProgress = data.leaveProgress
        nextEventAt = data.nextEventAt
        nextRegrowthAt = data.nextRegrowthAt
        updateCalendar(announce: false)
        recomputeStaffing()
        updateEconomy()
        return true
    }
}
