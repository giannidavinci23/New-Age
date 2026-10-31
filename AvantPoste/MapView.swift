import SwiftUI

struct MapView: View {
    @Environment(Game.self) private var game
    let tool: Tool?
    let onTap: (Int) -> Void

    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private static let baseTile: CGFloat = 44
    private static let zoomRange: ClosedRange<CGFloat> = 0.6...1.6

    var body: some View {
        let size = MapView.baseTile * (zoom * pinch).clamped(to: MapView.zoomRange)
        let highlights = highlightedTiles
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<Game.rows, id: \.self) { y in
                    HStack(spacing: 0) {
                        ForEach(0..<Game.cols, id: \.self) { x in
                            let i = Game.index(x, y)
                            TileView(tile: game.tiles[i], season: game.season, size: size,
                                     highlighted: highlights.contains(i), badge: badge(for: i))
                                .onTapGesture { onTap(i) }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            )
            .padding(28)
        }
        .defaultScrollAnchor(.center)
        .background(Color(red: 0.12, green: 0.34, blue: 0.52))
        .simultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { value, state, _ in state = value.magnification }
                .onEnded { value in zoom = (zoom * value.magnification).clamped(to: MapView.zoomRange) }
        )
    }

    private var highlightedTiles: Set<Int> {
        guard let tool else { return [] }
        return Set(game.tiles.indices.filter { isTarget($0, for: tool) })
    }

    private func isTarget(_ i: Int, for tool: Tool) -> Bool {
        switch tool {
        case .build(let type):
            return game.placementError(type, at: i, checkCost: false) == nil
        case .clear:
            return game.tiles[i].terrain == .forest
        case .demolish:
            guard let building = game.tiles[i].building else { return false }
            return building != .camp && building != .lighthouse
        }
    }

    private func badge(for i: Int) -> StaffBadge {
        let tile = game.tiles[i]
        guard let building = tile.building, building.maxWorkers > 0 else { return .none }
        if tile.paused { return .paused }
        let workers = game.staff[i] ?? 0
        if workers == 0 { return .empty }
        return workers < building.maxWorkers ? .partial : .none
    }
}

enum StaffBadge {
    case none, paused, empty, partial
}

struct TileView: View {
    let tile: Tile
    let season: Season
    let size: CGFloat
    let highlighted: Bool
    let badge: StaffBadge

    var body: some View {
        ZStack {
            Rectangle().fill(groundColor)
            decoration
            if let building = tile.building {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color.white.opacity(0.3))
                    .padding(size * 0.07)
                Text(building.icon)
                    .font(.system(size: size * 0.58))
                    .grayscale(tile.paused ? 1 : 0)
                    .opacity(tile.paused ? 0.5 : 1)
            }
            if highlighted {
                RoundedRectangle(cornerRadius: size * 0.16)
                    .fill(Color.white.opacity(0.22))
                    .padding(2)
                RoundedRectangle(cornerRadius: size * 0.16)
                    .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .padding(2)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) { badgeView }
        .contentShape(Rectangle())
    }

    @ViewBuilder private var decoration: some View {
        switch tile.terrain {
        case .forest:
            Text(season != .winter && tile.variant == 2 ? "🌳" : "🌲")
                .font(.system(size: size * 0.64))
        case .rock:
            Text(tile.variant == 1 ? "⛰️" : "🪨")
                .font(.system(size: size * 0.54))
        case .water:
            if tile.variant % 2 == 1 {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: size * 0.36, height: size * 0.06)
                    .offset(x: tile.variant == 1 ? -size * 0.12 : size * 0.14,
                            y: tile.variant == 1 ? -size * 0.14 : size * 0.16)
            }
        case .grass:
            if tile.building == nil, tile.variant == 3, season != .winter {
                Text(season == .autumn ? "🍂" : "🌼")
                    .font(.system(size: size * 0.22))
                    .offset(x: -size * 0.22, y: size * 0.2)
            }
        }
    }

    @ViewBuilder private var badgeView: some View {
        switch badge {
        case .none:
            EmptyView()
        case .paused:
            badgeCircle("pause.fill", Color.gray)
        case .empty:
            badgeCircle("person.fill.xmark", Color.red)
        case .partial:
            badgeCircle("person.fill", Color.orange)
        }
    }

    private func badgeCircle(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size * 0.32, height: size * 0.32)
            .background(color, in: Circle())
            .padding(size * 0.04)
    }

    private var groundColor: Color {
        let base: (r: Double, g: Double, b: Double)
        switch (tile.terrain, season) {
        case (.water, .winter): base = (0.62, 0.79, 0.89)
        case (.water, _): base = (0.21, 0.53, 0.78)
        case (.rock, .winter): base = (0.80, 0.82, 0.84)
        case (.rock, _): base = (0.63, 0.60, 0.54)
        case (_, .spring): base = (0.56, 0.79, 0.40)
        case (_, .summer): base = (0.44, 0.70, 0.31)
        case (_, .autumn): base = (0.77, 0.66, 0.33)
        case (_, .winter): base = (0.90, 0.93, 0.95)
        }
        let shade = [0.0, 0.025, -0.02, 0.04][tile.variant % 4]
        let dim = tile.terrain == .forest ? 0.84 : 1
        return Color(red: base.r * dim + shade, green: base.g * dim + shade, blue: base.b * dim + shade)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
