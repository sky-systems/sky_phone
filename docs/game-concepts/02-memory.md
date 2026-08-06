# Memory

## Kurzidee

Spieler decken jeweils zwei Karten auf und suchen gleiche Paare. Ziel ist es, das Spielfeld mit
möglichst wenigen Zügen und in kurzer Zeit abzuräumen.

## App

- Vorgesehene App-ID: `memory`
- Arbeitstitel: `Memory`
- Datenbesitz: Gerät
- Persistenz: Bestzeit und niedrigste Zugzahl je Schwierigkeitsgrad

## Spielablauf und Steuerung

- Startansicht mit Auswahl der Spielfeldgröße.
- Karten werden durch Antippen aufgedeckt.
- Stimmen zwei Karten überein, bleiben sie sichtbar; ansonsten drehen sie sich nach einer kurzen,
  nicht blockierenden Animation zurück.
- Während der Rückdrehung werden weitere Eingaben ignoriert.
- Abschlussansicht zeigt Zeit, Züge und persönliche Bestleistung.

## MVP

- Drei Größen: 3×4, 4×4 und 4×5.
- Originale Symbolpaare auf Basis einfacher Formen und phone-eigener Icons.
- Neuer zufälliger Aufbau pro Runde.
- Pausierbare Zeitmessung, wenn die App verlassen wird.
- Keine Hinweise, Joker oder Themenpakete im ersten Schritt.

## Tests und Abnahme

- Jedes Symbol kommt genau zweimal vor und die Kartenmischung verändert nicht die Paare.
- Ein Doppelklick auf dieselbe Karte zählt nicht als Paar.
- Mehr als zwei Karten können nie gleichzeitig als aktive Auswahl offen sein.
- Eine abgeschlossene Runde wird genau einmal gewertet.

