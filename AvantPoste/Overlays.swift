import SwiftUI

struct ToastStack: View {
    @Environment(Game.self) private var game

    var body: some View {
        VStack(spacing: 6) {
            ForEach(game.toasts) { toast in
                Text(toast.text)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(color(toast.kind).opacity(0.93), in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .animation(.spring(duration: 0.35), value: game.toasts)
        .allowsHitTesting(false)
    }

    private func color(_ kind: Toast.Kind) -> Color {
        switch kind {
        case .info: Color(red: 0.2, green: 0.25, blue: 0.32)
        case .good: Color(red: 0.15, green: 0.5, blue: 0.3)
        case .bad: Color(red: 0.72, green: 0.22, blue: 0.2)
        }
    }
}

struct OfferCard: View {
    @Environment(Game.self) private var game

    var body: some View {
        Group {
            if let offer = game.offer {
                VStack(alignment: .leading, spacing: 10) {
                    Text("🧳 Un marchand propose un échange")
                        .font(.subheadline.weight(.bold))
                    HStack(spacing: 8) {
                        Text("Donner \(offer.give.label)")
                        Image(systemName: "arrow.right")
                        Text("Recevoir \(offer.receive.label)")
                    }
                    .font(.callout.weight(.semibold))
                    ProgressView(value: (offer.remaining / Game.offerDuration).clamped(to: 0...1))
                        .tint(.orange)
                    HStack {
                        Button("Refuser") { game.resolveOffer(accept: false) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Accepter") { game.resolveOffer(accept: true) }
                            .buttonStyle(.borderedProminent)
                            .disabled(!game.canAfford(offer.give))
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .padding(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: game.offer)
    }
}

struct EndOverlay: View {
    @Environment(Game.self) private var game
    let onRestart: () -> Void

    var body: some View {
        let won = game.status == .won
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(won ? "🗼" : "🏚️")
                    .font(.system(size: 76))
                Text(won ? "Le Grand Phare brille !" : "L'avant-poste est abandonné")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(won
                     ? "Des navires accostent de toutes parts : votre colonie est devenue un port prospère."
                     : "Tous les colons sont partis. La nature reprend ses droits.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("👥 \(game.population) habitants · An \(game.year), \(game.season.name.lowercased())")
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 4)
                VStack(spacing: 10) {
                    if won {
                        Button { game.continueAfterWin() } label: {
                            Text("Continuer à jouer").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button { restart() } label: {
                            Text("Nouvelle colonie").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button { restart() } label: {
                            Text("Fonder une nouvelle colonie").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(26)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
            .padding(28)
        }
    }

    private func restart() {
        onRestart()
        game.newGame()
    }
}
