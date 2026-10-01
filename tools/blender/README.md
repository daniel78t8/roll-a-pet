# Blender-Prüfwerkzeuge für die Pet-Überarbeitung

Alle Skripte laufen ausschließlich in Blender (Programm oder `bpy`-Modul). Sie **öffnen Dateien nur
lesend und speichern keine `.blend`** – die Originale bleiben unverändert.

| Skript | Zweck |
|---|---|
| `setup_bpy.sh` | Installiert Blender als Python-Modul im Cloud-Container (Standard: 5.2.2 LTS). |
| `pet_audit.py` | Bestandsaufnahme: Geometrie, Normalen, Löcher, Duplikate, lose/schwebende Teile, UVs, Materialien, fehlende Bilder, Skalierung, Ursprünge, Hierarchien, Rigs, Actions und Loop-Sprünge. Ergebnis: `audit.md`/`audit.json` pro Datei und `summary.md`. |
| `pet_views.py` | Kontaktbogen pro Pet mit festem Licht-Rig: Vorder-, Seiten-, Rück-, Dreiviertel- und Draufsicht, Nahansicht, 96-px-Kleinansicht, Silhouette, Clay, Normalen-Check (rot = Rückseite sichtbar), heller und dunkler Hintergrund. |
| `selftest_build.py` | Baut eine Prüfdatei mit absichtlich eingebauten Fehlern und ein fehlerfreies Kontroll-Pet. Das sind keine Spiel-Pets. |

## Aufruf

```bash
# Cloud-Container
bash tools/blender/setup_bpy.sh ~/.venv-bpy
~/.venv-bpy/bin/python tools/blender/pet_audit.py pets/original/*.blend --out review/audit
~/.venv-bpy/bin/python tools/blender/pet_views.py pets/original/*.blend --out review/views

# Eigenes Blender (Windows/macOS/Linux)
blender -b --factory-startup --python tools/blender/pet_audit.py -- datei.blend --out review/audit
```

`pet_views.py`: `--engine CYCLES|BLENDER_EEVEE`, `--res 512`, `--samples 24`,
`--group auto|scene|collection`. Mit `auto` wird eine `.blend` mit mindestens zwei obersten
Sammlungen pro Sammlung gerendert, sonst die ganze Szene. Importierte FBX-, OBJ- und GLB-Dateien
werden immer als ganze Szene gerendert.

## Selbsttest (zuletzt am 01.10.2026 mit Blender 5.2.2 ausgeführt)

```bash
~/.venv-bpy/bin/python tools/blender/selftest_build.py /tmp/selftest/selftest.blend
~/.venv-bpy/bin/python tools/blender/pet_audit.py /tmp/selftest/selftest.blend --out /tmp/selftest/audit
~/.venv-bpy/bin/python tools/blender/pet_views.py /tmp/selftest/selftest.blend --out /tmp/selftest/views
```

Im Testobjekt `TestPet_Broken` wurden alle eingebauten Fehler erkannt:

- loser Vertex
- nicht angewendete und negative Skalierung
- komplett nach innen zeigende Normalen sowie drei einzeln gekippte Flächen
- 13 doppelte Flächen
- Loch (12 offene Kanten)
- leerer und ungenutzter Material-Slot
- schwebendes Teil (Abstand 0,52)
- fehlende Textur
- Wertsprung im Idle-Loop

Beim Kontroll-Pet `TestPet_Clean` meldet die Prüfung nur „UV verzerrt 16,7 %“. Das ist kein
Fehlalarm, sondern die echte Pol-Verzerrung einer Standard-UV-Kugel (48 von 288 Flächen).

## Grenzen

- „Schwebende Teile“ werden per Bounding-Box-Abstand erkannt. Das ist ein Hinweis, kein Beweis,
  und muss im Kontaktbogen geprüft werden.
- „Normalen nach innen“ lässt sich nur für geschlossene Teile sicher bestimmen. Bei offenen
  Flächen hilft der Normalen-Pass (rot).
- UV-Überlappung kann bei gespiegelten UVs gewollt sein. Texeldichte-Abweichungen werden nur als
  Information ausgegeben, weil sie oft Absicht sind (z. B. mehr Auflösung für das Gesicht).
