import Combine
import SwiftUI

enum Tool: Hashable {
    case build(BuildingType)
    case clear
    case demolish
}

private struct InspectedTile: Identifiable {
    let id: Int
}

struct ContentView: View {
    @Environment(Game.self) private var game
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenHelp") private var hasSeenHelp = false

    @State private var tool: Tool?
    @State private var inspected: InspectedTile?
    @State private var showColony = false
    @State private var showObjectives = false
    @State private var showHelp = false
    @State private var confirmNewGame = false
    @State private var lastTick = Date()
    @State private var successes = 0
    @State private var failures = 0

    private let clock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HUDView(showColony: $showColony, showObjectives: $showObjectives,
                    showHelp: $showHelp, confirmNewGame: $confirmNewGame)
            MapView(tool: tool, onTap: handleTap)
                .overlay(alignment: .top) { ToastStack() }
                .overlay(alignment: .bottom) { OfferCard() }
            BuildBar(tool: $tool)
        }
        .overlay {
            if game.status != .playing {
                EndOverlay { tool = nil }
            }
        }
        .sheet(item: $inspected) { item in
            BuildingSheet(index: item.id)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showColony) {
            ColonySheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showObjectives) {
            ObjectivesSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet()
        }
        .confirmationDialog("Abandonner cette colonie et en fonder une nouvelle ?",
                            isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("Nouvelle colonie", role: .destructive) {
                tool = nil
                game.newGame()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: successes)
        .sensoryFeedback(.error, trigger: failures)
        .onAppear {
            if !hasSeenHelp {
                hasSeenHelp = true
                showHelp = true
            }
        }
        .onReceive(clock) { now in
            // The rules stay on screen without the colony starving behind them.
            if !showHelp { game.advance(now.timeIntervalSince(lastTick)) }
            lastTick = now
        }
        .onChange(of: scenePhase) { _, phase in
            lastTick = Date()
            if phase != .active { game.save() }
        }
    }

    private func handleTap(_ index: Int) {
        let error: String?
        switch tool {
        case .build(let type)?:
            error = game.build(type, at: index)
        case .clear?:
            error = game.clearForest(at: index)
        case .demolish?:
            error = game.demolish(at: index)
        case nil:
            let tile = game.tiles[index]
            if tile.building != nil {
                inspected = InspectedTile(id: index)
            } else if tile.terrain != .grass {
                game.notify(tile.terrain.hint)
            }
            return
        }
        if let error {
            game.notify(error, .bad)
            failures += 1
        } else {
            successes += 1
            if tool == .build(.lighthouse) { tool = nil }
        }
    }
}
