# Einzelspieler-Games für sky_phone

Dieser Ordner enthält kleine, getrennt umsetzbare Konzepte für Einzelspieler-Games. Jedes Spiel
wird als eigene Phone-App mit eigener App-ID, eigenem Icon und eigener Vue-Ansicht umgesetzt. Es
gibt keine gemeinsame Arcade-App.

## Geplante Apps und Reihenfolge

1. [Snake](01-snake.md) – guter Einstieg für Spielfeld, Eingabe und Highscore-Persistenz.
2. [Memory](02-memory.md) – rundenbasiert und ohne Echtzeit-Loop.
3. [2048](03-2048.md) – Zustandslogik, Animationen und fortsetzbare Partien.
4. [Minesweeper](04-minesweeper.md) – Schwierigkeitsgrade und sichere Feldgenerierung.
5. [Tower Stack](05-tower-stack.md) – Timing-Spiel mit kurzer aktiver Animationsschleife.
6. [Sky Flappy](06-sky-flappy.md) – Flappy-Bird-artiges Spiel mit eigener Gestaltung.
7. [Neon Drop](07-neon-drop.md) – schnelles Blockpuzzle mit steigender Fallgeschwindigkeit.

## Gemeinsame technische Leitlinien

- Alle Spiele laufen vollständig im Vue-Frontend. Der MVP benötigt keine Lua-, NUI- oder
  Server-Callbacks.
- Highscores, Einstellungen und optionale Spielstände gehören zum physischen Gerät. Eine spätere
  Implementierung soll dafür einen gemeinsamen Pinia-Store und einen eigenen Gerätenamespace
  `games` verwenden, damit verschiedene Spiele sich beim Speichern nicht gegenseitig überschreiben.
- Es gibt im MVP keine globalen Ranglisten, serverseitigen Belohnungen, Ingame-Währung oder andere
  spielrelevante Serverzustände.
- Jede App wird in `PhoneAppId`, `PHONE_APPS`, den Benachrichtigungsvorgaben und beiden
  Übersetzungsquellen registriert. Icons werden als originale WebP-Dateien abgelegt.
- Echtzeitspiele verwenden `requestAnimationFrame` nur während einer aktiven Runde. Beim Verlassen
  der App, Pausieren oder Schließen des Phones wird der Loop beendet.
- Steuerung muss mit Maus beziehungsweise Touch funktionieren. Tastatursteuerung darf im
  Browser-Entwicklungsmodus zusätzlich angeboten werden.
- Spielregeln und Zufallslogik werden in testbare TypeScript-Utilities ausgelagert. Vue-Komponenten
  übernehmen Darstellung, Navigation und Eingabe.
- Gestaltung, Namen, Sounds und Assets bleiben eigenständig. Bekannte Spiele dienen nur als
  Beschreibung des Spielprinzips.

## Gemeinsame Definition of Done

- Die App startet über ein eigenes Homescreen-Icon und kehrt über den Home-Indikator sauber zurück.
- Eine neue Runde, Pause, Neustart und Game Over funktionieren ohne hängende Timer oder Animationen.
- Highscore und Einstellungen bleiben nach Schließen und erneutem Öffnen des Phones erhalten.
- Alle sichtbaren Texte laufen über `phone.t(...)`.
- Spiellogik besitzt fokussierte Vitest-Tests; `pnpm test`, `pnpm typecheck`, `pnpm lint` und der
  echte Frontend-Build sind erfolgreich.
