import Foundation

/// Small deterministic generator so a seed always gives the same map.
struct SplitMix64: RandomNumberGenerator, Codable {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Random values on a coarse lattice, smoothly interpolated: gives blobs of terrain.
struct ValueNoise {
    private let cell: Double
    private let width: Int
    private let values: [Double]

    init(cols: Int, rows: Int, cell: Double, rng: inout SplitMix64) {
        self.cell = cell
        width = Int(Double(cols) / cell) + 2
        let height = Int(Double(rows) / cell) + 2
        var values: [Double] = []
        for _ in 0..<(width * height) {
            values.append(Double.random(in: 0...1, using: &rng))
        }
        self.values = values
    }

    func sample(_ x: Int, _ y: Int) -> Double {
        let fx = Double(x) / cell, fy = Double(y) / cell
        let x0 = Int(fx), y0 = Int(fy)
        let tx = smooth(fx - Double(x0)), ty = smooth(fy - Double(y0))
        let top = lerp(value(x0, y0), value(x0 + 1, y0), tx)
        let bottom = lerp(value(x0, y0 + 1), value(x0 + 1, y0 + 1), tx)
        return lerp(top, bottom, ty)
    }

    private func value(_ gx: Int, _ gy: Int) -> Double { values[gy * width + gx] }
    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

enum MapGenerator {
    static func generate(seed: UInt64) -> [Tile] {
        let cols = Game.cols, rows = Game.rows
        var rng = SplitMix64(seed: seed)
        let waterNoise = ValueNoise(cols: cols, rows: rows, cell: 4, rng: &rng)
        let forestNoise = ValueNoise(cols: cols, rows: rows, cell: 3, rng: &rng)
        let rockNoise = ValueNoise(cols: cols, rows: rows, cell: 2.5, rng: &rng)
        let coast = Int.random(in: 0..<4, using: &rng)
        let center = (x: cols / 2, y: rows / 2)

        var tiles: [Tile] = []
        tiles.reserveCapacity(cols * rows)
        for y in 0..<rows {
            for x in 0..<cols {
                // 1 on the coast side of the map, 0 on the opposite side.
                let edge: Double
                switch coast {
                case 0: edge = Double(y) / Double(rows - 1)
                case 1: edge = 1 - Double(y) / Double(rows - 1)
                case 2: edge = Double(x) / Double(cols - 1)
                default: edge = 1 - Double(x) / Double(cols - 1)
                }
                let distance = hypot(Double(x - center.x), Double(y - center.y))
                let water = 0.5 * waterNoise.sample(x, y) + 0.85 * pow(edge, 3)

                let terrain: Terrain
                if distance < 2.5 {
                    terrain = .grass
                } else if water > 0.75 {
                    terrain = .water
                } else if rockNoise.sample(x, y) > 0.75 {
                    terrain = .rock
                } else if forestNoise.sample(x, y) > 0.6 {
                    terrain = .forest
                } else {
                    terrain = .grass
                }
                tiles.append(Tile(terrain: terrain, variant: Int.random(in: 0..<4, using: &rng)))
            }
        }

        ensure(.forest, atLeast: 6, within: 5, of: center, in: &tiles, rng: &rng)
        ensure(.rock, atLeast: 3, within: 6, of: center, in: &tiles, rng: &rng)
        tiles[Game.index(center.x, center.y)].building = .camp
        return tiles
    }

    /// Grows a cluster of `terrain` near the camp when the noise left too little of it.
    private static func ensure(_ terrain: Terrain, atLeast needed: Int, within radius: Double,
                               of center: (x: Int, y: Int), in tiles: inout [Tile], rng: inout SplitMix64) {
        var area: Set<Int> = []
        for i in tiles.indices {
            let p = Game.coords(i)
            let d = hypot(Double(p.x - center.x), Double(p.y - center.y))
            if d >= 2.5 && d <= radius { area.insert(i) }
        }
        var count = area.filter { tiles[$0].terrain == terrain }.count
        guard count < needed else { return }

        let grass = area.filter { tiles[$0].terrain == .grass }.sorted()
        guard let start = grass.randomElement(using: &rng) else { return }
        var frontier = [start]
        var visited: Set<Int> = []
        while count < needed, !frontier.isEmpty {
            let i = frontier.removeFirst()
            guard visited.insert(i).inserted, area.contains(i), tiles[i].terrain == .grass else { continue }
            tiles[i].terrain = terrain
            count += 1
            frontier += Game.neighbors(of: i).shuffled(using: &rng)
        }
    }
}
