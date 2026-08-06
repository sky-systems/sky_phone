# Neon Drop

## Kurzidee

`Neon Drop` ist eine eigenständige Einzelspieler-App über fallende Energieblöcke. Der Spieler dreht
und verschiebt Formen aus vier Zellen, um im Reaktor vollständige Reihen zu bilden. Volle Reihen
lösen sich auf, geben Punkte und schaffen Platz für weitere Formen. Das bekannte Grundprinzip dient
nur als Genrevorbild; Name, Oberfläche, Grafik, Texte und Sounds sind eigenständig.

## App

- App-ID: `neon-drop`
- Name: `Neon Drop`
- Datenbesitz: physisches Phone-Gerät
- Persistenz: bester Punktestand, höchste Linienzahl und Soundeinstellung
- Technische Trennung: eigene View sowie eigener Ordner für Engine, Store, Typen und Audio

## Spielregeln

- Das Spielfeld besitzt zehn Spalten und achtzehn sichtbare Reihen.
- Jede Form besteht aus vier Energiezellen. Es gibt sieben unterschiedliche Formen.
- Eine Form fällt automatisch und kann seitlich bewegt oder gedreht werden.
- Eine vollständige Reihe wird entfernt; darüberliegende Blöcke rutschen nach unten.
- Mehrere gleichzeitig entfernte Reihen geben deutlich mehr Punkte.
- Nach jeweils acht entfernten Reihen steigt das Level und die automatische Fallzeit wird kürzer.
- Eine Runde endet, wenn eine neue Form nicht mehr am oberen Spielfeldrand eingesetzt werden kann.

## Steuerung

- Linker und rechter Button beziehungsweise horizontaler Swipe: Form verschieben.
- Drehen-Button, Aufwärts-Swipe oder Pfeiltaste nach oben: Form drehen.
- Abwärts-Button beziehungsweise kurzer Abwärts-Swipe: Form eine Zelle schneller senken.
- Schnellfall-Button, langer Abwärts-Swipe oder Leertaste: Form sofort auf der Zielposition ablegen.
- Pause und Rückkehr ins Spielhauptmenü sind jederzeit über die obere Leiste möglich.

## Spielgefühl und Effekte

- Eine halbtransparente Geisterform zeigt die sichere Zielposition des aktuellen Blocks.
- Ein kurzer Impuls markiert das Einrasten; gelöschte Reihen erzeugen einen hellen Reaktorblitz.
- Eigene synthetische Sounds unterscheiden Bewegung, Drehung, Landung, Linienabbau und Game Over.
- Die nächste Form wird in einer separaten Vorschau angezeigt.
- Das Tempo steigt gleichmäßig mit dem Level, besitzt aber eine spielbare Untergrenze von 110 ms.

## Wertung

- Eine Reihe: `100 × Level`
- Zwei Reihen: `300 × Level`
- Drei Reihen: `500 × Level`
- Vier Reihen: `800 × Level`
- Schnellfall: zwei Zusatzpunkte pro übersprungener Zelle
- Kontrolliertes Absenken: ein Zusatzpunkt pro Zelle

## Tests und Abnahme

- Alle Formen starten innerhalb der Spielfeldbreite.
- Seitliche Bewegung und Drehung können keine belegten Zellen oder Wände durchdringen.
- Drehungen am Rand verwenden begrenzte, nachvollziehbare Wandkorrekturen.
- Vollständige Reihen werden korrekt entfernt und darüberliegende Reihen sinken ab.
- Punkte, Linien, Level und Fallintervall steigen nach den definierten Regeln.
- Schnellfall landet auf derselben Zielposition wie wiederholtes automatisches Absenken.
- Pause, Hauptmenü und Verlassen der App stoppen jeden aktiven Timer.
