# Tower Stack

## Kurzidee

Ein horizontal bewegter Block wird per Antippen fallengelassen. Nur der überlappende Teil bleibt
liegen; dadurch wird die nächste Ebene schmaler. Ziel ist der höchste mögliche Turm.

## App

- Vorgesehene App-ID: `tower-stack`
- Arbeitstitel: `Tower Stack`
- Datenbesitz: Gerät
- Persistenz: Höchster Turm, höchste Punktzahl und Soundeinstellung

## Spielablauf und Steuerung

- Eine Runde startet durch Antippen des Displays.
- Jeder weitere Tipp setzt den aktuell bewegten Block ab.
- Perfekte Platzierungen erhalten einen Bonus und können einen kleinen Breitenanteil zurückgeben.
- Fällt ein Block vollständig daneben, endet die Runde.
- Die Bewegung wird mit zunehmender Höhe schneller.

## MVP

- Eine aktive `requestAnimationFrame`-Schleife nur während der Runde.
- Klare Schatten und Kontraste statt aufwendiger 3D-Darstellung.
- Punktzahl entspricht der erreichten Höhe plus Perfekt-Boni.
- Kurze Treffer-, Perfekt- und Game-Over-Sounds.

## Tests und Abnahme

- Überlappung und verbleibende Blockbreite werden unabhängig von der Darstellung getestet.
- Perfekte Platzierungen verwenden eine feste, nachvollziehbare Toleranz.
- Geschwindigkeit bleibt innerhalb definierter Grenzen.
- Beim Pausieren oder Verlassen der App wird die Animationsschleife zuverlässig beendet.

