# Sky Flappy

## Kurzidee

Eine Flappy-Bird-artige Einzelspieler-App mit eigener Figur und eigener Gestaltung. Durch Antippen
erhält die Figur einen kurzen Aufwärtsimpuls und muss zwischen Hindernissen hindurchfliegen.

## App

- Vorgesehene App-ID: `sky-flappy`
- Arbeitstitel: `Sky Flappy`
- Datenbesitz: Gerät
- Persistenz: Highscore, gewähltes Design und Soundeinstellung

## Spielablauf und Steuerung

- Antippen startet die Runde und löst anschließend jeden Flügelschlag aus.
- Schwerkraft zieht die Figur kontinuierlich nach unten.
- Jedes vollständig passierte Hindernispaar gibt einen Punkt.
- Kollision mit Hindernis, Boden oder Oberkante beendet die Runde.
- Nach Game Over kann sofort eine neue Runde gestartet werden.

## MVP

- Eigene abstrakte Sky-Figur, eigene Hindernisse und eigene Sounds; keine übernommenen Namen,
  Grafiken oder Audiodateien des bekannten Vorbilds.
- Zufällige, aber spielbare Öffnungshöhen mit Mindestabständen.
- Langsam ansteigende Geschwindigkeit, ohne unfaire Sprünge.
- Eine aktive `requestAnimationFrame`-Schleife mit zeitbasierter Bewegung statt frameabhängiger
  Physik.
- Pause bei App-Wechsel oder geschlossenem Phone.

## Tests und Abnahme

- Physikschritte liefern bei gleicher verstrichener Zeit reproduzierbare Ergebnisse.
- Hindernisöffnungen bleiben innerhalb des sichtbaren und spielbaren Bereichs.
- Ein Hindernispaar kann nur einmal gewertet werden.
- Kollisionen berücksichtigen die tatsächlichen Hitboxen und nicht nur den Mittelpunkt.
- Nach App-Wechsel laufen weder Physik noch Hindernisgenerierung weiter.

