# Avant-Poste

Jeu de gestion de colonie en temps réel pour iPhone (SwiftUI, iOS 17+).

Fondez un avant-poste sur une île générée au hasard, nourrissez vos colons, passez l'hiver et bâtissez le Grand Phare 🗼.

## Lancer le jeu

1. Ouvrir `AvantPoste.xcodeproj` dans Xcode (il faut un Mac).
2. Choisir un simulateur iPhone, puis ⌘R.

## Code

- `AvantPoste/Models.swift` : ressources, saisons, bâtiments (coûts, effets).
- `AvantPoste/Game.swift` : moteur (économie, population, événements, sauvegarde).
- `AvantPoste/MapGenerator.swift` : génération de la carte.
- Vues : `ContentView`, `HUDView`, `MapView`, `BuildBar`, `Sheets`, `Overlays`.
