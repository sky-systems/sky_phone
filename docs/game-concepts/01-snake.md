# Snake

## Kurzidee

Ein klassisches Rasterspiel: Die Schlange bewegt sich automatisch, sammelt Früchte, wird länger und
darf weder den Rand noch den eigenen Körper berühren. Eine Runde dauert typischerweise ein bis drei
Minuten.

## App

- Vorgesehene App-ID: `snake`
- Arbeitstitel: `Snake`
- Datenbesitz: Gerät
- Persistenz: Highscore, gewählte Geschwindigkeit und optional pausierter Spielstand

## Spielablauf und Steuerung

- Startansicht mit Highscore, Schwierigkeitsgrad und Startknopf.
- Vier große Wischbereiche oder Richtungsbuttons steuern die Schlange.
- Im Browser-Entwicklungsmodus funktionieren zusätzlich Pfeiltasten und WASD.
- Direkte Richtungswechsel in die entgegengesetzte Richtung werden ignoriert.
- Nach Game Over werden Punktzahl, Highscore, Neustart und Rückkehr zum Menü angezeigt.

## MVP

- Festes Spielfeld mit gut lesbarer Rastergröße für das Phone-Display.
- Drei Geschwindigkeiten: entspannt, normal und schnell.
- Ein Punkt pro Frucht; Geschwindigkeit steigt optional in festen Stufen.
- Pausenfunktion, wenn die App in den Hintergrund wechselt.
- Eigene Farben, Früchte und Sounds ohne fremde Assets.

## Tests und Abnahme

- Bewegung, Wachstum, Fruchtplatzierung und Kollisionen werden als reine TypeScript-Logik getestet.
- Eine Frucht darf niemals auf der Schlange erscheinen.
- Mehrere schnelle Eingaben dürfen keine unzulässige Rückwärtsbewegung verursachen.
- Nach Verlassen der App läuft kein Timer weiter.

