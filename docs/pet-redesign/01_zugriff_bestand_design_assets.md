# Pet-Redesign – Schritt 1: Zugriff, Bestand, Gestaltungsvorschlag, Asset-Liste

Stand: 01.10.2026 · Branch `claude/funny-planck-a585xy`

> **Kurzfassung:** Blender läuft in dieser Sitzung, aber **keine einzige Pet-Datei und kein Katalog
> ist vorhanden**. Die Bestandsaufnahme der Pets ist deshalb noch nicht möglich. Es gibt hier keine
> erfundenen Befunde. Abschnitt 3 nennt genau, was fehlt. Der Gestaltungsvorschlag (Abschnitt 4)
> ist tierunabhängig und vorläufig. Die Asset-Liste (Abschnitt 5) enthält nur, was sich ohne die
> Pet-Dateien schon festlegen lässt. **Zwingend muss jetzt kein Bild zu ChatGPT.**

---

## 1. Zugriffsprüfung (tatsächlich ausgeführt)

| Prüfpunkt | Ergebnis |
|---|---|
| Blender in dieser Cloud-Sitzung | **Ja.** Blender 5.2.2 LTS als Python-Modul (`bpy`, von PyPI) installiert. Headless-Rendern getestet: Cycles (CPU) ✔, EEVEE ✔ (über Mesa-Software-OpenGL, nachinstalliert), Workbench ✔. FBX- und glTF-Import vorhanden, OBJ ist eingebaut. |
| Blender auf deinem PC (`blender-mcp` aus `setup-mcp.ps1`) | **Nein.** Dieser MCP-Server ist nur in Claude Code auf deinem Rechner registriert. In dieser Cloud-Sitzung gibt es keine Blender-MCP-Werkzeuge, also keinen Zugriff auf dein lokales Blender. |
| `download.blender.org` | Vom Netzwerk-Proxy gesperrt (HTTP 403). Deshalb läuft Blender über das `bpy`-Paket von PyPI. |
| Pet-Dateien im Repository | **Keine.** `daniel78t8/roll-a-pet` enthält nur `setup-mcp.ps1`. Einziger weiterer Branch: `claude/inspiring-dijkstra-j4dpc3`, gleicher Stand. |
| Pet-Dateien im Container | **Keine.** Das gesamte Dateisystem wurde nach `.blend`, `.blend1`, `.fbx`, `.obj`, `.glb`, `.gltf`, `.rbxm`, `.rbxl`, `.rbxmx` und `.rbxlx` durchsucht: kein Treffer. |
| Weitere Repositories | Keine. Für diese Sitzung ist nur `daniel78t8/roll-a-pet` freigegeben. |
| Pet-Katalog (Namen, Seltenheiten, aktiv/ausgemustert) | **Nicht vorhanden.** Die Zahlen 47 aktiv, 5 ausgemustert und 376 Kombinationen lassen sich nicht mit Dateien abgleichen. Geprüft ist nur die Arithmetik: 3+5+4+4+6+6+5+5+4+5 = 47 ✔, 47 × 4 Varianten × 2 (Shiny ja/nein) = 376 ✔. |
| Roblox Studio und Spielskripte | Nicht geöffnet und nicht angefasst, wie vorgegeben. |
| Sichtbarkeit des Repositorys | **Öffentlich.** Alles, was hochgeladen wird (Pet-Modelle, Texturen), ist für jeden sichtbar. Falls das nicht gewollt ist: Repository vor dem Upload auf privat stellen. |

**Vorbereitet und getestet** (siehe `tools/blender/README.md`): `pet_audit.py` und `pet_views.py`
führen die Bestandsaufnahme automatisch aus, sobald Dateien da sind. Getestet wurde nur an einem
Testobjekt mit absichtlich eingebauten Fehlern, nicht an Pets. Alle eingebauten Fehler wurden
erkannt. Beim fehlerfreien Kontroll-Pet gab es keinen Fehlalarm.

## 2. Bestandsaufnahme – offen

| Frage | Stand |
|---|---|
| Welche Pets sind vorhanden? | Offen – keine Dateien und kein Katalog. |
| Welche Varianten und Mutationen existieren bereits? | Offen. |
| Welche Bestandteile lassen sich weiterverwenden? | Offen. |
| Was passt optisch nicht zusammen? | Offen. |
| Welche konkreten Fehler sind nachweisbar? | Offen. |
| Welche Verbesserungen pro Pet? | Offen. Der tierunabhängige Vorschlag steht in Abschnitt 4. |

Sobald die Dateien da sind, läuft pro Pet: `audit.md` (Messwerte und Fehler) plus Kontaktbogen
(18 Ansichten unter festem Licht). Daraus entsteht die Übersicht pro Pet, die dann diesen
Abschnitt ersetzt.

## 3. Was ich von dir brauche

| # | Datei / Information | Format | Wofür | Pflicht |
|---|---|---|---|---|
| D1 | Modelldateien aller **47 aktiven Pets** | Am liebsten `.blend` mit eingepackten Texturen (*Datei › Externe Daten › Ressourcen packen*). Sonst `.fbx`, `.glb` oder `.obj` + `.mtl` + alle Texturen. | Bestandsaufnahme und Arbeitskopien | **Ja** |
| D2 | Vorhandene Varianten (Gold, Diamond, Rainbow, Shiny), falls es dafür eigene Modelle, Materialien oder Texturen gibt. Sonst eine kurze Beschreibung, wie sie heute aussehen. | Dateien wie D1 oder Text | Frage „Welche Varianten existieren bereits?“ | **Ja** |
| D3 | Katalog als **Datenliste** (kein Skript): Pet-Name/-ID, Seltenheit, aktiv/ausgemustert, zugehörige Modelldatei, Fortbewegungsart (läuft, hüpft, fliegt, schwebt) | `.csv` oder Tabelle im Chat | Abgleich der Zahlen 47/5/376 und Zuordnung | **Ja** |
| D4 | Namen der **5 ausgemusterten Pets** | Text | Damit sie nachweislich unangetastet bleiben. Dateien brauche ich nur, wenn sie Meshes oder Materialien mit aktiven Pets teilen. | Ja (nur Namen) |
| D5 | Deine **Blender-Version** | z. B. „4.2 LTS“ | Ich arbeite in genau dieser Version, damit die Dateien bei dir sauber aufgehen. In Blender 5.x gespeicherte Dateien sind in 4.x nicht zuverlässig nutzbar. | **Ja** |
| D6 | Sollen **Exportdateien** entstehen? Falls ja: Zielformat (z. B. FBX), Dreiecks-Budget pro Pet, Texturgröße, Bildrate der Animationen | Text | Entscheidet, ob Materialien zu Texturen gebacken werden und Rigs exportfähig sein müssen | **Ja** |
| D7 | Optional: Screenshots der heutigen Darstellung je Variante | `.png` | Nur zum Vergleich. Eine Darstellung im Spiel bestätige ich nicht. | Optional |

**Übergabeweg:** in dieses Repository unter `pets/original/<PetName>/…` committen, auf diesem
Branch oder einem beliebigen anderen (dann den Namen nennen).

- Git erlaubt bis 100 MB pro Datei, der Upload über die GitHub-Weboberfläche bis 25 MB.
- Größere Dateien über Git LFS. Das ist hier verfügbar.
- **Achtung:** Das Repository ist öffentlich.

Falls die Pets **nur in Roblox Studio** existieren, brauche ich einen Export, den du selbst
erstellen müsstest. Ich darf Roblox Studio nicht öffnen.

**Alternative:** Wenn du Claude Code lokal mit deinem `setup-mcp.ps1` startest, kann ich dort
direkt in deinem Blender arbeiten. Aus dieser Cloud-Sitzung heraus geht das nicht.

## 4. Gestaltungsvorschlag (vorläufig, gilt für alle Pets)

Wird nach der Bestandsaufnahme pro Pet konkretisiert. Grundsatz: Jedes Pet bleibt erkennbar
dasselbe Tier. Farben, Merkmale und Grundform werden verfeinert, nicht ersetzt.

### 4.1 Stil: „weiche Vinyl-Sammelfigur“

**Shading:** Stilisiertes PBR, also Farbe, Rauheit, Metall und Normal-Map, ohne Konturlinien und
ohne Cel-Shading. Gründe:

- Diese Maps lassen sich in Blender als Texturen backen und in übliche Spiel-Engines übertragen.
- Toon-Shader und Konturlinien hängen am Renderer, und Konturlinien verdoppeln die Geometrie.
- Ob und wie das im Spiel aussieht, prüfe ich nicht, da der Auftrag nur in Blender läuft.

**Proportionen:**

- Kopf je nach Tier etwa 40–55 % der Gesamthöhe
- kompakter Rumpf, kurze runde Gliedmaßen
- Silhouette-Test bei 96 px (im Kontaktbogen enthalten)

**Gesicht:**

- Augen als eigene Geometrie: Iris mit Verlauf, Pupille, zwei Glanzpunkte (groß oben links,
  klein unten rechts), bei **allen** Pets dieselbe Lichtrichtung
- Blick leicht nach innen und unten gerichtet, gegen den „starren Blick“
- Lider für das Blinzeln

**Formübergänge:**

- Kopf und Rumpf überlappen bewusst und werden als „gewollte Durchdringung“ gekennzeichnet,
  oder sie werden verschmolzen
- keine Lücken, keine schwebenden Teile

**Oberflächen:**

- glatte Schattierung mit Weighted Normals
- harte Kanten nur, wo sie zum Tier gehören: Hörner, Krallen, Diamond-Facetten

**Konsistenz:** gleiche Augenkonstruktion, gleiches Rauheitsspektrum und gleiches Licht-Rig für
alle Pets. Größenunterschiede bleiben so, wie sie heute sind. Eine Änderung schlage ich nur
nach Befund vor.

### 4.2 Material- und Variantensystem

**Gemeinsame Node-Gruppen** in `pets/shared/PetShared_Library.blend`:

- `NG_PetBase` – Grundfarbe, Bauchverlauf, Abdunklung in Vertiefungen (AO), Rauheit, leichter Sheen
- `NG_Mut_Gold`, `NG_Mut_Diamond`, `NG_Mut_Rainbow` – die drei Mutationen
- `NG_Shiny_Overlay` – lässt sich mit jeder Variante kombinieren

**Aufbau pro Pet:**

- **ein** Mesh (die Grundfigur)
- vier Varianten-Objekte `PET_<Name>_Normal`, `…_Gold`, `…_Diamond` und `…_Rainbow`, die sich
  dieses Mesh teilen; das Material hängt am Objekt
- Shiny als zuschaltbare Schicht und Effekt-Sammlung

So entstehen **47 Grundmodelle**, nicht 376.

**Gesicht:** Augen, Nase und Mund übernehmen die Mutation nicht oder nur leicht getönt, damit das
Gesicht immer lesbar bleibt.

| Variante | Oberfläche (Startwerte) | Effekt |
|---|---|---|
| **Normal** | Grundfarbe des Tiers, Rauheit 0,45–0,6, Sheen ≈ 0,2, sanfter Bauchverlauf, keine Emission | keiner, kein Dauer-Glow |
| **Gold** | Metallisch 1,0, Grundton etwa `#F2B33D`, Vertiefungen bis etwa `#8A5A12`, Rauheit 0,18–0,25 | Schmaler Lichtreflex wandert in etwa 3 s über einzelne Körperbereiche. 4–6 kleine warme Funken (runde Punkte) nah am Körper. |
| **Diamond** | Eisblau `#9FE8FF` bis Cyan `#4FD3F0`. Facetten über eine Normal-Map, gebacken aus einer bewusst facettierten Kopie mit gleichmäßigen Flächen; die Silhouette bleibt gleich. Transmission ≤ 0,3, Rauheit 0,05–0,1, IOR 1,45. | Dezentes inneres Leuchten in dicken Bereichen. 2–3 kurze Glanzpunkte als kurze Linien auf der Oberfläche. |
| **Rainbow** | Geordneter Farbverlauf entlang des Körpers (Sättigung ≈ 0,6, Helligkeit ≈ 0,9), leichte Irisierung | Farbverlauf wandert langsam (1 Umlauf ≈ 8 s). Kurzer Schweif (≈ 0,4 s) bei Bewegung. 3–5 kleine fünfzackige Sterne. |
| **Shiny** (+ jede der vier) | Blasser Kantenglanz weiß-lila `#F4E9FF` | 3–5 weiße Vierzack-Funkeln umkreisen den Kopf in Kopfhöhe und blinken versetzt (je 0,6 s). Nie vor dem Gesicht. |

**Unterscheidbarkeit:** Die Effekte von Gold, Diamond, Rainbow und Shiny haben bewusst
verschiedene Formen: runde Punkte, kurze Linien, fünfzackige Sterne, Vierzack-Funkeln. Deshalb
bleibt Shiny auf jeder Variante erkennbar, auch auf Gold.

**Licht:** Alle Varianten werden unter demselben Licht-Rig abgestimmt. Die Wirkung kommt aus dem
Material, nicht aus Render-Einstellungen.

### 4.3 Animationen

| Action | Dauer | Inhalt |
|---|---|---|
| `<Pet>_Idle_Loop` | 4 s (120 Frames bei 30 fps – Bildrate nach D6) | Atmung ±1,5–2 %, leichtes Heben und Senken, Ohren und Schwanz zeitversetzt, Blinzeln bei ≈ 1,6 s und 3,6 s; nahtloser Loop |
| `<Pet>_Move_Loop` | ≈ 1 s | Laufen, Hüpfen, Fliegen oder Schweben, je nach Tier (laut D3) |
| `<Pet>_Present` | ≈ 2,5 s | Kurze Präsentation: Hüpfer, halbe Drehung, Pose |
| `FX_<Mutation>_Reveal` | ≈ 1,5 s | 0,4 s Aufbau, 0,3 s Höhepunkt, 0,8 s Ausblenden |

Rig pro Körperbau: Wurzel, Körper, Kopf, Ohren, Schwanz, Flügel, Beine, Lider. Die Loop-Nähte
prüft `pet_audit.py` automatisch. Durchdringungen prüfe ich an gerenderten Einzelbildern.

### 4.4 Effekte und Export trennen

Jedes Pet bekommt zwei Sammlungen:

- `EXPORT`: Mesh, Rig, Actions und gebackene Texturen
- `PREVIEW_ONLY`: Blender-Partikel, animierte Shader und Vorschau-Licht

Effekt-Sprites werden als PNG mit dokumentiertem Raster geliefert.

### 4.5 Ordner und Namen

```
pets/original/     unverändert, wird nie gespeichert
pets/work/<Pet>/<Pet>.blend
pets/shared/PetShared_Library.blend   Node-Gruppen, Effekte, Licht-Rig
pets/textures/<Pet>/  ·  pets/textures/shared/
pets/review/       Kontaktbögen, Vorher/Nachher, Vorschauvideos
pets/export/       nur falls gewünscht
```

### 4.6 MVP

Nach der Bestandsaufnahme schlage ich ein repräsentatives Pet vor:

- typische Merkmale (Ohren, Schwanz, Beine)
- mittlere Seltenheit und mittlere Komplexität

Daran entstehen alle vier Varianten plus Shiny, alle Animationen und die Prüfszene. Erst nach
deiner Abnahme übertrage ich das auf die übrigen 46.

## 5. Asset-Liste

**Logik:**

- Was Blender exakt erzeugen kann, wird dort erzeugt: Materialien, Augen und Effekt-Sprites mit
  sauberem Alphakanal und genauem Raster.
- ChatGPT ist für Konzeptbilder sinnvoll, später eventuell für gemalte Muster.
- Körpertexturen werden erst angefordert, wenn die UV-Aufteilung feststeht und ich die
  UV-Vorlage geliefert habe.

### 5A. Von ChatGPT – gemeinsam für alle Pets

| # | Dateiname | Verwendung | Zweck | Format / Maße | Hintergrund | Motiv, Farben, Perspektive, Stil | Technische Anforderungen | MVP? |
|---|---|---|---|---|---|---|---|---|
| A1 | `REF_shared_style_lookboard_v1.png` | gemeinsam (alle 47) | **Konzeptbild** – Stilziel | PNG 1536 × 1024 | ausgefüllt, hellgrau `#D9DDE3` | Drei Beispieltiere (Katze, Vogel, Baby-Drache) als Vinyl-Figuren, Dreiviertelansicht, weiches Licht oben links | Gleiche Größe und Bodenhöhe, ≥ 80 px Rand, kein Text | **optional** (empfohlen) |
| A2 | `REF_shared_mutation_lookboard_v1.png` | gemeinsam (alle 47) | **Konzeptbild** – Mutationen | PNG 1536 × 1024 | ausgefüllt, `#D9DDE3` | Dieselbe Katze 8×: oben Normal, Gold, Diamond, Rainbow; unten dieselben vier mit Shiny | Raster 4 × 2, gleiche Pose und Größe, ≥ 40 px Abstand, kein Text | **optional** |
| A3 | `TEX_shared_eye_expressions_atlas_1024.png` | gemeinsam (alle 47) | **Augen** (2D-Atlas) | PNG 1024 × 1024, 4 Felder à 512 × 512 | **transparent** (echter Alphakanal) | Augenpaar: offen · halb geschlossen · geschlossen · fröhlich (^ ^) | Jede Augengruppe mittig, ≥ 64 px Abstand zum Feldrand, kein gemaltes Schachbrettmuster | **bedingt**: nur falls die Gesichter heute 2D-Decals sind und dieser Stil bleiben soll. Mein Standard sind modellierte Augen. |

Die Prompts sind auf Deutsch und lassen sich direkt einfügen.

**A1 – Prompt**
```
Erstelle ein Stil-Referenzbild (Konzeptbild, keine Textur) für niedliche 3D-Haustiere eines Sammelspiels. Querformat 1536×1024 Pixel, einfarbig hellgrauer Hintergrund (#D9DDE3), kein Text, keine Schrift, kein Logo, keine Umgebung.
Zeige nebeneinander drei verschiedene kleine Haustiere als gerenderte 3D-Figuren im Stil hochwertiger Vinyl-Sammelfiguren: links eine Katze (vierbeinig, Ohren, Schwanz), Mitte ein kleiner runder Vogel (kurze Flügel), rechts ein Baby-Drache (kleine Hörner, Flügel, Schwanz).
Alle drei in derselben Dreiviertelansicht von vorne rechts, gleich groß, auf derselben Bodenlinie, mit weichem Kontaktschatten, mindestens 80 Pixel Abstand zueinander und zum Bildrand.
Proportionen: großer runder Kopf (etwa die halbe Körperhöhe), kompakter Körper, kurze rundliche Beine.
Gesicht: große glänzende Augen mit dunkler Pupille, ein großer Lichtreflex oben links und ein kleiner unten rechts im Auge, kleine Nase, freundlicher, leicht lächelnder Ausdruck, Blick leicht zum Betrachter.
Oberfläche: glatt und seidenmatt, sanfte Farbverläufe (Bauch heller), leichte Abdunklung in Vertiefungen, keine einzelnen Fellhaare, keine Konturlinien, kein Cel-Shading.
Licht: weiches Hauptlicht von oben links, schwaches Aufhelllicht von rechts, dezentes Kantenlicht von hinten.
Farben: harmonische, leicht gedeckte Pastell- bis Mitteltöne, keine Neonfarben. Keine Accessoires, keine Kleidung.
```

**A2 – Prompt**
```
Erstelle ein Konzeptbild (keine Textur) für Material-Varianten eines niedlichen 3D-Haustiers. Querformat 1536×1024 Pixel, einfarbig hellgrauer Hintergrund (#D9DDE3), kein Text, keine Beschriftung.
Zeige dieselbe kleine Vinyl-Katzenfigur (großer runder Kopf, kompakter Körper, kurze Beine, große glänzende Augen) achtmal in einem Raster aus 4 Spalten und 2 Zeilen, jeweils identische Pose, Dreiviertelansicht von vorne rechts, gleiche Größe, mindestens 40 Pixel Abstand zwischen den Figuren und zum Rand. Alle unter exakt derselben Beleuchtung (weiches Licht von oben links).
Obere Zeile von links nach rechts:
1) Normal: cremeweiß-orange, seidenmatt, weiche Farbverläufe, kein Leuchten.
2) Gold: poliertes warmes Gold, dunklere Goldtöne in Vertiefungen, helle Reflexe an Kopf und Rücken, ein schmaler heller Lichtstreifen über der Schulter, 4 bis 6 winzige warme runde Goldfunken nah am Körper.
3) Diamond: eisblau bis cyan, bewusst gestaltete gleichmäßige Kristallfacetten mit klaren Kanten, nur leicht durchscheinend, sodass Form und Gesicht klar erkennbar bleiben, dezentes inneres Leuchten, 2 bis 3 kurze weiße Glanzlinien.
4) Rainbow: weicher geordneter Regenbogenverlauf über den Körper (pastellig, nicht grell), leicht schimmernde Oberfläche, 3 bis 5 kleine bunte fünfzackige Sterne nahe der Figur.
Untere Zeile: dieselben vier Varianten in derselben Reihenfolge, jeweils zusätzlich mit „Shiny“: ein blasser weiß-lila Kantenglanz entlang der Silhouette und 3 bis 5 kleine weiße Vierzack-Funkeln, die in Kopfhöhe seitlich um den Kopf schweben (nie vor dem Gesicht).
Augen und Gesicht bleiben in allen acht Varianten dunkel und gut lesbar. Keine Konturlinien, kein Cel-Shading, keine Accessoires.
```

**A3 – Prompt** (nur auf meine Anforderung hin)
```
Erstelle ein PNG mit echtem transparentem Hintergrund (Alphakanal, kein gemaltes Schachbrettmuster), 1024×1024 Pixel, aufgeteilt in 4 gleich große Felder (2×2, je 512×512 Pixel). Kein Text, keine Rahmen, keine Hilfslinien.
In jedem Feld genau mittig ein Paar niedlicher Cartoon-Augen für ein 3D-Haustier, von vorne gesehen, mit mindestens 64 Pixel Abstand zum Feldrand:
oben links: weit geöffnet – dunkelbraune bis schwarze Pupille, Iris mit leichtem Verlauf, ein großer weißer Lichtreflex oben links und ein kleiner unten rechts;
oben rechts: halb geschlossen – oberes Lid bedeckt die obere Hälfte, gleiche Reflexe;
unten links: geschlossen – zwei weich geschwungene dunkle Lidlinien;
unten rechts: fröhlich – zwei nach oben gebogene Bögen (^ ^).
Saubere, glatte Formen mit weichem Kantenübergang (1–2 Pixel), einheitliche Linienstärke, gleicher Augenabstand und gleiche Augengröße in allen vier Feldern, keine Schatten außerhalb der Augen.
```

### 5B. In Blender erzeugt – „Kein externes Bild erforderlich“

| # | Ergebnis | Verwendung | Zweck | Format / Maße | Hintergrund | Form, Rand, Helligkeit, Transparenz | Raster / Abspielen | MVP? |
|---|---|---|---|---|---|---|---|---|
| B1 | `NG_PetBase`, `NG_Mut_Gold`, `NG_Mut_Diamond`, `NG_Mut_Rainbow`, `NG_Shiny_Overlay` | gemeinsam (alle 47) | Materialien | Node-Gruppen; bei Export gebacken je Pet: BaseColor, Normal, Roughness, Metallic (Größe nach D6) | – | prozedural | – | **MVP** |
| B2 | Augen-Material und -Geometrie | gemeinsam | Augen | prozedural | – | Iris-Verlauf, Pupille, 2 Glanzpunkte | – | **MVP** |
| B3 | `FX_shared_sparkle4_sheet.png` | gemeinsam: Shiny (weiß-lila getönt), Diamond-Glanz (cyan getönt) | Effektgrafik | PNG 1024 × 512 | transparent | Vierzack-Funkeln mit schlanken Strahlen; harter heller Kern, weicher Glow-Rand; Mitte 100 %, Strahlspitzen → 0 %; reines Weiß, Tönung im Effekt | 4 × 2 Raster, Zellen 256 px, 8 Bilder, zeilenweise oben links → unten rechts, 12 fps: aufgehen → voll → abklingen | **MVP** |
| B4 | `FX_shared_spark_dot.png` | gemeinsam: Gold-Funken | Effektgrafik | PNG 128 × 128 | transparent | runder Punkt, weicher Rand, radial 100 % → 0 % | Einzelbild | **MVP** |
| B5 | `FX_shared_star5.png` | gemeinsam: Rainbow-Sterne | Effektgrafik | PNG 256 × 256 | transparent | fünfzackiger Stern mit gerundeten Spitzen, scharfe Kante (1 px Antialiasing), leichter Außen-Glow 15 % | Einzelbild | **MVP** |
| B6 | `FX_shared_rainbow_trail.png` | gemeinsam: Rainbow-Schweif | Effektgrafik | PNG 256 × 32 | transparent | Farbspektrum entlang der Länge; Deckkraft links 100 % → rechts 0 %; weiche Ober- und Unterkante | Einzelbild, wird gestreckt | **MVP** |
| B7 | `FX_shared_glint_streak.png` | gemeinsam: Gold-Lichtreflex, Reveal-Höhepunkt | Effektgrafik | PNG 512 × 128 | transparent | schmaler Lichtstreifen, Mitte hell, weicher Rand, Enden laufen aus | Einzelbild | **MVP** |
| B8 | `FX_shared_glow_soft.png` | gemeinsam: Reveal-Sequenz | Effektgrafik | PNG 256 × 256 | transparent | radialer Glow, sehr weicher Rand, Mitte 80 % | Einzelbild | optional |
| B9 | `UVT_<Pet>_1024.png` | je Pet | **UV-Vorlage** für 5C/C2 | PNG 1024 × 1024 | transparent | UV-Kanten 2 px, Inseln beschriftet | – | nur wenn C2 nötig |

### 5C. Pro Pet – erst nach der Bestandsaufnahme

| # | Dateiname | Zweck | Wann |
|---|---|---|---|
| C1 | `REF_<pet_id>_concept_v1.png` (PNG 1536 × 1024, ausgefüllt `#D9DDE3`) | **Konzeptbild** zur Richtungsklärung | Nur für Pets, deren Bestandsaufnahme zeigt, dass die Zielrichtung unklar ist (z. B. sehr grobes Modell). Fertige Prompts liefere ich dann zusammen mit dem Vorher-Bild aus dem Kontaktbogen, das du an ChatGPT anhängst, damit das Tier erkennbar bleibt. |
| C2 | `TEX_<pet_id>_markings_1024.png` (PNG 1024 × 1024) | **UV-gebundene Textur** für gemalte Muster (Flecken, Streifen), die prozedural nicht gut gehen | **Jetzt nicht anfordern.** Erst wenn die UVs final sind und ich `UVT_<pet_id>_1024.png` geliefert habe. |

Prompt-Vorlage C1, wird nach der Bestandsaufnahme pro Pet ausgefüllt:
```
Ich hänge ein Bild meines bisherigen 3D-Haustiers „[NAME]“ an (ein [TIERART]). Erstelle eine verbesserte Version DESSELBEN Tiers als Konzeptbild (keine Textur): Querformat 1536×1024 Pixel, einfarbig hellgrauer Hintergrund (#D9DDE3), kein Text.
Zeige es dreimal nebeneinander: Vorderansicht, Seitenansicht (Blick nach links), Dreiviertelansicht von vorne rechts – gleiche Größe, gleiche Bodenlinie, mindestens 80 Pixel Abstand.
Behalte unbedingt bei: [MERKMALE, z. B. „spitze Ohren mit rosa Innenseite, buschiger Schwanz“], Grundfarben [FARBEN].
Verbessere: [BEFUNDE aus der Bestandsaufnahme].
Stil: hochwertige Vinyl-Sammelfigur, großer runder Kopf, kompakter Körper, kurze Gliedmaßen, große glänzende Augen mit zwei Lichtreflexen (groß oben links, klein unten rechts), seidenmatte Oberfläche, weiche Farbverläufe, keine Konturlinien, kein Cel-Shading, keine Accessoires.
```

### 5D. Zusammenfassung

| | Anzahl |
|---|---|
| Jetzt zwingend an ChatGPT | **0** |
| Jetzt optional an ChatGPT | 2 (A1, A2) |
| Bedingt (Entscheidung nach der Bestandsaufnahme) | 1 gemeinsam (A3), bis zu 47 Konzeptbilder (C1), Muster-Texturen (C2) nur bei Bedarf |
| Gemeinsam nutzbare PNGs | A1, A2, A3, B3–B8 – alle für alle 47 Pets |

## 6. Prüfung zurückgelieferter Bilder

Jedes Bild von ChatGPT prüfe ich vor der Verwendung in Blender:

- Auflösung
- echter Alphakanal statt gemaltem Schachbrett
- Randabstand
- Raster
- Stil im Vergleich zu A1
- bei Texturen: Passung zur UV-Vorlage

Passt etwas nicht, nenne ich die konkrete Korrektur, zum Beispiel „Der Hintergrund muss
transparent sein“ oder „Die Kontur braucht 64 px Abstand zum Feldrand“.
