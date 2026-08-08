# FiveM-Natives für eine Wetteranzeige

Stand: 8. August 2026. Berücksichtigt wurden ausschließlich die offizielle
[FiveM Native Reference](https://docs.fivem.net/natives/) und die zugehörigen
Quellen im Repository [`citizenfx/natives`](https://github.com/citizenfx/natives).
Alle hier genannten GTA-V-Natives sind clientseitig auszuführen.

## Ergebnis

FiveM/GTA V besitzt **keine echte stündliche Forecast-API**. Die Natives geben den
aktuellen Wetterübergang, dessen zwei Wettertypen und aktuelle Umweltwerte aus.
Sie liefern weder eine Liste späterer Wettertypen noch Zeitpunkte oder eine
Restdauer bis zum nächsten Wechsel.

Eine ehrliche Wetter-App kann daher anzeigen:

- den aktuellen Übergang vom vorherigen zum nächsten Wettertyp,
- den Anteil des Zielwetters am laufenden Übergang,
- aktuelle Regen-, Schnee- und Windwerte,
- die aktuelle Spielzeit.

Mehrere Stundenkarten dürfen daraus nur als **lokale Projektion** abgeleitet
werden. Ohne einen eigenen serverseitigen Wetterplan sind sie keine native
Vorhersage. Insbesondere verrät `GET_NEXT_WEATHER_TYPE_HASH_NAME` nur das Ziel
des gerade im Spiel geführten Übergangs und nicht den übernächsten Wettertyp.

## Relevante Natives

| Lua-Aufruf | Hash | Rückgabe | Verwendbarkeit |
| --- | --- | --- | --- |
| `GetPrevWeatherTypeHashName()` | `0x564B884A05EC45A3` | `Hash` | Erster/ausgehender Wettertyp des aktuellen Übergangs. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetPrevWeatherTypeHashName.md) |
| `GetNextWeatherTypeHashName()` | `0x711327CD09C8F162` | `Hash` | Zweiter/Ziel-Wettertyp des aktuellen Übergangs. Kein Forecast-Array. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetNextWeatherTypeHashName.md) |
| `GetWeatherTypeTransition()` | `0xF3BBE884A14BB413` | drei Outputwerte: `Hash`, `Hash`, `float` | Liest beide Wettertypen und `percentWeather2` gemeinsam. Der native C-Name ist `_GET_WEATHER_TYPE_TRANSITION`. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetWeatherTypeTransition.md) |
| `GetRainLevel()` | `0x96695E368AD855F3` | `float` | Aktuelle Regenintensität, nicht die Wahrscheinlichkeit zukünftigen Regens. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetRainLevel.md) |
| `GetSnowLevel()` | `0xC5868A966E5BE3AE` | `float` | Aktuelles Schnee-Level, keine Schneevorhersage. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetSnowLevel.md) |
| `GetWindSpeed()` | `0xA8CF1CC0AFCD3F12` | `float` | Aktuelle Windgeschwindigkeit in Metern pro Sekunde. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetWindSpeed.md) |
| `GetWindDirection()` | `0x1F400FEF721170DA` | `Vector3` | Aktueller Windrichtungsvektor. Eine Überschrift kann mit `GetHeadingFromVector_2d(direction.x, direction.y)` berechnet werden. [Quelle](https://github.com/citizenfx/natives/blob/master/MISC/GetWindDirection.md) |
| `GetClockHours()` | `0x25223CA6B4D20B7F` | `int` | Aktuelle Ingame-Stunde `0` bis `23`. [Quelle](https://github.com/citizenfx/natives/blob/master/CLOCK/GetClockHours.md) |
| `GetClockMinutes()` | `0x13D2B8ADD79640F2` | `int` | Aktuelle Ingame-Minute. [Quelle](https://github.com/citizenfx/natives/blob/master/CLOCK/GetClockMinutes.md) |
| `GetClockSeconds()` | `0x494E97C2EF27C470` | `int` | Aktuelle Ingame-Sekunde, falls für Aktualisierung/Anzeige benötigt. [Quelle](https://github.com/citizenfx/natives/blob/master/CLOCK/GetClockSeconds.md) |

Die Signatur von `_GET_WEATHER_TYPE_TRANSITION` lautet offiziell:

```c
void _GET_WEATHER_TYPE_TRANSITION(
    Hash* weatherType1,
    Hash* weatherType2,
    float* percentWeather2
);
```

`percentWeather2` beschreibt den Anteil des zweiten Wettertyps im laufenden
Übergang. Die offizielle Dokumentation nennt jedoch keine Zeiteinheit, keine
Restdauer und keine garantierte Umrechnung dieses Werts in Ingame-Stunden.
Darum darf der Wert nicht als „in X Stunden“ ausgegeben werden.

## Wettertypen und Hash-Abgleich

Die Hashes können gegen `joaat('CLEAR')`, `joaat('EXTRASUNNY')`,
`joaat('CLOUDS')`, `joaat('OVERCAST')`, `joaat('RAIN')`, `joaat('THUNDER')`,
`joaat('CLEARING')`, `joaat('SMOG')`, `joaat('FOGGY')`, `joaat('XMAS')`,
`joaat('SNOW')`, `joaat('SNOWLIGHT')`, `joaat('BLIZZARD')`,
`joaat('NEUTRAL')` und die weiteren vom aktuellen Game-Build unterstützten
Wettertypen verglichen werden. Die Native-Dokumentation verweist hierfür auf
[`SET_WEATHER_TYPE_NOW`](https://github.com/citizenfx/natives/blob/master/MISC/SetWeatherTypeNow.md).

Nicht aus dem Wettertyp erfinden sollte die App Temperatur, Luftfeuchtigkeit,
Niederschlagswahrscheinlichkeit, Sonnenaufgang oder eine garantierte Dauer. Für
diese Werte existiert in der offiziellen GTA-V/FiveM-Native-Referenz keine
entsprechende Forecast-Ausgabe.

## Lua und OAL

Das Resource-Manifest aktiviert in diesem Projekt experimentelles OAL. Laut der
offiziellen [OAL-Dokumentation](https://docs.fivem.net/docs/scripting-reference/resource-manifest/#use_experimental_fxv2_oal)
liefert OAL genauere Native-Rückgabetypen und schnellere Aufrufe, toleriert aber
keine falschen Parametertypen; zudem funktioniert implizites Vector-Unpacking
nicht.

Für diese Wetterabfrage folgt daraus:

- Die generierten Lua-Namen (`GetRainLevel`, `GetWindSpeed` usw.) statt frei
  erfundener Wrapper oder falsch typisierter `Citizen.InvokeNative`-Aufrufe
  verwenden.
- `GetWeatherTypeTransition()` ist besonders testrelevant, weil die native
  Signatur drei Pointer-Outputs enthält. Die Werte in Lua als mehrere
  Rückgabewerte des generierten Wrappers behandeln; keine Zahlen oder Lua-Tabellen
  als vermeintliche Pointer übergeben.
- `GetWindDirection()` gibt einen `vector3` zurück. Bei einem Folgenotenaufruf
  wie `GetHeadingFromVector_2d` explizit `direction.x, direction.y` übergeben.
- Wetter-Hashes als Hash/Integer behandeln und per `joaat('...')` vergleichen;
  nicht auf eine Rückgabe des Wettertyp-Namens als String vertrauen.
- Die Werte clientseitig erfassen und nur die kleinste benötigte strukturierte
  Payload an die NUI senden.

## Empfehlung für `sky_phone`

Die App sollte „Nächste Stunden“ nur dann wörtlich als Prognose bezeichnen, wenn
`sky_phone` oder ein ausdrücklich unterstützter, isolierter Wetteranbieter einen
serverseitigen Zeitplan mit zukünftigen Zuständen bereitstellt. Bei reinen
Natives ist fachlich korrekt:

1. „Jetzt“ aus Wettertyp 1/2, Übergangsanteil, Regen, Schnee und Wind bilden.
2. Den Zieltyp als „Im Übergang zu …“ anzeigen.
3. Keine sechs verschiedenen Stundenwerte simulieren. Alternativ dieselbe
   Transition als vorsichtige Projektion kennzeichnen, ohne erfundene exakte
   Temperaturen oder Wahrscheinlichkeiten.
