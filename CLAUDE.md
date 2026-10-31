# Avant-Poste : notes pour Claude

- Jeu iOS en SwiftUI (iOS 17+, `@Observable`). Les textes du jeu sont en français.
- Le projet Xcode utilise un groupe synchronisé : tout fichier `.swift` ajouté dans `AvantPoste/` est compilé automatiquement, sans toucher au `project.pbxproj`.
- Compiler (Mac avec Xcode uniquement) : `xcodebuild -project AvantPoste.xcodeproj -scheme AvantPoste -destination 'generic/platform=iOS Simulator' build`. Sans Xcode (Claude Code sur le web, Linux), impossible de compiler : relire le Swift avec soin et le signaler.
- Modifier `Game.SaveData`, ou un type qu'elle contient comme `TradeOffer`, rend la sauvegarde existante illisible : le jeu repart alors sur une nouvelle colonie.
- Équilibrage : coûts et effets des bâtiments dans `Models.swift`, taux de production dans `Game.output(at:)`.
