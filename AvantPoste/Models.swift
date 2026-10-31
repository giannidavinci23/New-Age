import Foundation

enum Terrain: String, Codable {
    case grass, forest, rock, water

    var hint: String {
        switch self {
        case .grass: "Prairie : terrain constructible."
        case .forest: "Forêt : un bûcheron 🛖 à côté produit du bois, ou défrichez-la 🪓."
        case .rock: "Roches : une carrière ⛏️ à côté extrait de la pierre."
        case .water: "Eau : parfaite pour une pêcherie 🎣… et un jour pour le Grand Phare 🗼."
        }
    }
}

enum Resource: String, CaseIterable, Identifiable, Codable {
    case food, wood, stone, gold

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .food: "🍞"
        case .wood: "🪵"
        case .stone: "🪨"
        case .gold: "🪙"
        }
    }

    /// Used in "Pas assez de bois", "Pas assez d'or"…
    var partitive: String {
        switch self {
        case .food: "de nourriture"
        case .wood: "de bois"
        case .stone: "de pierre"
        case .gold: "d'or"
        }
    }
}

/// An amount of each resource: the colony's stock, a cost, a reward or a rate per second.
struct Stock: Codable, Equatable {
    var food = 0.0
    var wood = 0.0
    var stone = 0.0
    var gold = 0.0

    subscript(resource: Resource) -> Double {
        get {
            switch resource {
            case .food: food
            case .wood: wood
            case .stone: stone
            case .gold: gold
            }
        }
        set {
            switch resource {
            case .food: food = newValue
            case .wood: wood = newValue
            case .stone: stone = newValue
            case .gold: gold = newValue
            }
        }
    }

    var entries: [(resource: Resource, amount: Double)] {
        Resource.allCases.compactMap { r in self[r] != 0 ? (resource: r, amount: self[r]) : nil }
    }

    var label: String {
        entries.map { "\(Int($0.amount)) \($0.resource.icon)" }.joined(separator: " ")
    }
}

enum Season: Int, Codable, CaseIterable {
    case spring, summer, autumn, winter

    var name: String {
        switch self {
        case .spring: "Printemps"
        case .summer: "Été"
        case .autumn: "Automne"
        case .winter: "Hiver"
        }
    }

    var icon: String {
        switch self {
        case .spring: "🌱"
        case .summer: "☀️"
        case .autumn: "🍂"
        case .winter: "❄️"
        }
    }

    var farmMultiplier: Double {
        switch self {
        case .spring: 0.8
        case .summer: 1.2
        case .autumn: 1.0
        case .winter: 0
        }
    }

    var announcement: String {
        switch self {
        case .spring: "🌱 Le printemps est là : les champs reverdissent."
        case .summer: "☀️ L'été : les récoltes sont au plus haut."
        case .autumn: "🍂 L'automne : faites des réserves avant l'hiver !"
        case .winter: "❄️ L'hiver : les fermes s'arrêtent et les maisons brûlent du bois."
        }
    }
}

enum TaxLevel: Int, Codable, CaseIterable, Identifiable {
    case low, normal, high

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .low: "Bas"
        case .normal: "Normal"
        case .high: "Élevé"
        }
    }

    var goldPerColonist: Double {
        switch self {
        case .low: 0.02
        case .normal: 0.04
        case .high: 0.07
        }
    }

    var happiness: Int {
        switch self {
        case .low: 10
        case .normal: 0
        case .high: -15
        }
    }

    var factorLabel: String {
        switch self {
        case .low: "Impôts bas"
        case .normal: "Impôts normaux"
        case .high: "Impôts élevés"
        }
    }
}

enum BuildingType: String, Codable, CaseIterable, Identifiable {
    case camp, house, farm, fishery, lumber, quarry, warehouse, market, tavern, fountain, lighthouse

    var id: String { rawValue }

    static let buildable: [BuildingType] = [
        .house, .farm, .fishery, .lumber, .quarry, .warehouse, .market, .tavern, .fountain, .lighthouse,
    ]

    var name: String {
        switch self {
        case .camp: "Campement"
        case .house: "Maison"
        case .farm: "Ferme"
        case .fishery: "Pêcherie"
        case .lumber: "Bûcheron"
        case .quarry: "Carrière"
        case .warehouse: "Entrepôt"
        case .market: "Marché"
        case .tavern: "Taverne"
        case .fountain: "Fontaine"
        case .lighthouse: "Grand Phare"
        }
    }

    var icon: String {
        switch self {
        case .camp: "🏕️"
        case .house: "🏠"
        case .farm: "🌾"
        case .fishery: "🎣"
        case .lumber: "🛖"
        case .quarry: "⛏️"
        case .warehouse: "📦"
        case .market: "🏪"
        case .tavern: "🍺"
        case .fountain: "⛲"
        case .lighthouse: "🗼"
        }
    }

    var summary: String {
        switch self {
        case .camp: "Le cœur de l'avant-poste. Loge 6 colons et stocke 150 de chaque ressource."
        case .house: "Loge 4 colons. Consomme du bois en hiver."
        case .farm: "Nourriture, sauf en hiver. +25 % près de l'eau."
        case .fishery: "Nourriture toute l'année, réduite en hiver. Au bord de l'eau."
        case .lumber: "Bois, selon le nombre de forêts voisines."
        case .quarry: "Pierre, selon le nombre de roches voisines."
        case .warehouse: "+150 de stockage pour chaque ressource."
        case .market: "+40 % de recettes fiscales."
        case .tavern: "+8 de bonheur (3 tavernes au plus)."
        case .fountain: "+4 de bonheur, sans employé (4 au plus)."
        case .lighthouse: "Merveille au bord de l'eau, 30 habitants requis. Victoire !"
        }
    }

    var cost: Stock {
        switch self {
        case .camp: Stock()
        case .house: Stock(wood: 15)
        case .farm: Stock(wood: 20)
        case .fishery: Stock(wood: 18)
        case .lumber: Stock(wood: 12)
        case .quarry: Stock(wood: 20, gold: 10)
        case .warehouse: Stock(wood: 30, stone: 20)
        case .market: Stock(wood: 35, stone: 20)
        case .tavern: Stock(wood: 30, stone: 25, gold: 20)
        case .fountain: Stock(stone: 30, gold: 15)
        case .lighthouse: Stock(wood: 150, stone: 250, gold: 200)
        }
    }

    var maxWorkers: Int {
        switch self {
        case .farm, .lumber, .quarry: 2
        case .fishery, .market, .tavern: 1
        default: 0
        }
    }

    var housing: Int {
        switch self {
        case .camp: 6
        case .house: 4
        default: 0
        }
    }

    var storage: Double {
        switch self {
        case .camp, .warehouse: 150
        default: 0
        }
    }

    /// Wood burnt per second in winter.
    var heating: Double {
        switch self {
        case .camp: 0.06
        case .house: 0.04
        default: 0
        }
    }

    /// Colonists fill jobs in this order: food first.
    var priority: Int {
        switch self {
        case .farm, .fishery: 0
        case .lumber: 1
        case .quarry: 2
        default: 3
        }
    }
}

struct Tile: Codable, Equatable {
    var terrain: Terrain
    var building: BuildingType?
    var paused = false
    /// Purely visual variation (shade, tree species…).
    var variant = 0
}

struct BuildingOutput {
    let resource: Resource
    let perSecond: Double
}

enum GameStatus: String, Codable {
    case playing, won, lost
}

struct Toast: Identifiable, Equatable {
    enum Kind { case info, good, bad }

    let id = UUID()
    let text: String
    let kind: Kind
}

struct TradeOffer: Codable, Equatable {
    var give: Stock
    var receive: Stock
    /// Real seconds before the merchant leaves, whatever the game speed; frozen while paused.
    var remaining: Double
}

struct HappinessFactor: Identifiable, Equatable {
    let label: String
    let value: Int

    var id: String { label }
}

enum Objective: Int, CaseIterable, Identifiable {
    case farm, lumber, pop10, winter, quarry, tavern, pop25, lighthouse

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .farm: "Construire une ferme"
        case .lumber: "Construire un bûcheron"
        case .pop10: "Atteindre 10 habitants"
        case .winter: "Survivre au premier hiver"
        case .quarry: "Construire une carrière"
        case .tavern: "Ouvrir une taverne"
        case .pop25: "Atteindre 25 habitants"
        case .lighthouse: "Bâtir le Grand Phare"
        }
    }

    var reward: Stock {
        switch self {
        case .farm: Stock(gold: 10)
        case .lumber: Stock(gold: 10)
        case .pop10: Stock(wood: 25)
        case .winter: Stock(gold: 30)
        case .quarry: Stock(wood: 20)
        case .tavern: Stock(stone: 30)
        case .pop25: Stock(gold: 60)
        case .lighthouse: Stock()
        }
    }
}
