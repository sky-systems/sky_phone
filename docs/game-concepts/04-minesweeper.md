# Minesweeper

## Kurzidee

Ein verdecktes Raster enthält Minen. Zahlen zeigen an, wie viele Minen an ein Feld grenzen. Ziel ist
es, alle sicheren Felder aufzudecken, ohne eine Mine zu treffen.

## App

- Vorgesehene App-ID: `minesweeper`
- Arbeitstitel: `Minesweeper`
- Datenbesitz: Gerät
- Persistenz: Bestzeit je Schwierigkeitsgrad und optionale laufende Partie

## Spielablauf und Steuerung

- Kurzes Antippen deckt ein Feld auf.
- Langes Drücken setzt oder entfernt eine Flagge.
- Das erste aufgedeckte Feld und seine unmittelbaren Nachbarn sind immer minenfrei.
- Leere Bereiche öffnen sich automatisch zusammenhängend.
- Minenzähler, Zeit und Neustartknopf bleiben während der Runde sichtbar.

## MVP

- Drei für das Phone angepasste Schwierigkeitsgrade.
- Zufällige Felder mit garantierter sicherer erster Aktion.
- Sieg-, Niederlage- und Neustartansicht.
- Keine täglichen Herausforderungen oder Hilfesysteme im ersten Schritt.

## Tests und Abnahme

- Die gewünschte Minenzahl wird exakt erzeugt und keine Mine liegt im geschützten Startbereich.
- Nachbarzahlen entsprechen den tatsächlich angrenzenden Minen.
- Automatisches Öffnen überschreitet keine nummerierten Grenzfelder.
- Markierte Felder werden durch normales Antippen nicht geöffnet.

