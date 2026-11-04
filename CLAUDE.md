# Avant-Poste : notes pour Claude

- Jeu iOS en SwiftUI (iOS 17+, `@Observable`). Les textes du jeu sont en français.
- Le projet Xcode utilise un groupe synchronisé : tout fichier `.swift` ajouté dans `AvantPoste/` est compilé automatiquement, sans toucher au `project.pbxproj`.
- Compiler (Mac avec Xcode uniquement) : `xcodebuild -project AvantPoste.xcodeproj -scheme AvantPoste -destination 'generic/platform=iOS Simulator' build`. Sans Xcode (Claude Code sur le web, Linux), impossible de compiler : relire le Swift avec soin et le signaler.
- Modifier `Game.SaveData`, ou un type qu'elle contient comme `TradeOffer`, rend la sauvegarde existante illisible : le jeu repart alors sur une nouvelle colonie.
- Équilibrage : coûts et effets des bâtiments dans `Models.swift`, taux de production dans `Game.output(at:)`.
- Production : `Game.rateBreakdown(for:)` est la seule source des taux (`rates`) et du détail affiché quand on touche une ressource ; toute nouvelle production ou consommation s'ajoute là. Les bonus des ateliers et de la forge passent par `Game.productionBonus(at:)`.
- Forêt : elle ne repousse que sur les cases boisées de la carte d'origine, recalculées depuis la graine (`MapGenerator.generate(seed:)`) au chargement. Modifier le générateur de carte change donc ces cases pour les parties en cours.
