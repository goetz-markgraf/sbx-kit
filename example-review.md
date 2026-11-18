# Review: `example/` gegen `features.md`

Stand: 2026-11-18

## Methode und Grenzen

Die Prüfung lief in einer Sandbox ohne `sbx`, `op` und Docker. Daher gilt:

| Art | Bedeutung |
|---|---|
| **[V]** verifiziert | Ich habe es ausgeführt. Das war nur bei `sbx-env.sh` möglich, mit einem Stub-`sbx` und Temp-Verzeichnissen unter `/tmp/opencode`. |
| **[D]** Doku-Abgleich | Ich habe es gegen die Docs von sbx, die Kit-Spec (v3) und opencode geprüft. |
| **[?]** nicht prüfbar | Das muss auf dem Host getestet werden. |

Das Verhalten der Kits, des Plugins, der Proxy-Injektion und der Mounts habe ich nicht ausgeführt. Alles dazu ist statisch bewertet.

Schweregrade: **Hoch** (Funktion oder Sicherheit real beeinträchtigt), **Mittel**, **Niedrig**.

## Gesamteindruck

Das Konzept ist solide und nah an den sbx-Idiomen: Kits als Mixins, proxy-verwalteter Credential, Secret per `op://`-Referenz, Allowlist für die Host-Config, Historie pro Sandbox, Parameter-Patterns an den Kit-Args. Die README ist ehrlich bei „Ungeprüft“.

Hauptprobleme:

1. ~~`sbx-env.sh` bricht ab dem **zweiten Start** ab, wenn die Host-Config schreibgeschützt ist (typisch bei Nix). [V]~~ Erledigt (I-8).
2. `sbx-env.sh` und `kits/` liegen im vom Agenten beschreibbaren Workspace. `sbx-env.sh` läuft ungeprüft auf dem Host. [D] Teilweise erledigt (I-3, S-1): Die Host-Logik liegt jetzt in `lifecycle.initialize`. Das dünne Skript und `kits/` bleiben im Workspace.
3. ~~Die Namensableitung per `sed` ist fragil. Ein Name wie `..` löscht alle Historien. [V]~~ Erledigt (I-1, I-2).
4. Das Feature „Provider austauschbar“ ist nur für OpenAI-kompatible APIs mit `Authorization: Bearer` erfüllt.
5. Provider-ID und Host stehen an mehreren Stellen. Die Allowlist der Config steht dreifach vor.

## Übersicht der Findings

| ID | Titel | Schwere |
|---|---|---|
| V-1 | Provider nur OpenAI-kompatibel mit Bearer-Header | Mittel |
| V-2 | Modellliste ohne Filter und ohne Metadaten | Mittel |
| V-3 | Plugin kein eigenständiges Artefakt | Niedrig |
| V-4 | Plugin ohne Fehlerbehandlung bei Netzfehlern und ohne Refresh | Mittel |
| V-5 | Historie: Persistenz über Neuaufsetzen nicht belegt, SQLite auf Mount offen | Mittel |
| V-6 | Netz „sehr restriktiv“ nur teilweise eingelöst | Mittel |
| V-7 | Kein Kontext für den Agenten (`agent-context`) | Niedrig |
| V-8 | Mehrere Provider nicht möglich, nicht dokumentiert | Niedrig |
| V-9 | README: Neu-Erstellen nach Tool-Änderung fehlt, „Verzeichnis kopieren“ mehrdeutig | Niedrig |
| W-1 | Provider-ID/Host an drei Stellen dupliziert | Mittel |
| W-2 | Config-Allowlist dreifach vorhanden | Mittel |
| W-3 | Gekoppelte Pfade und Namen über mehrere Dateien | Niedrig |
| W-4 | Inline-TypeScript und -Shell in YAML | Mittel |
| W-5 | `requires` fehlt in `llm-provider` und `opencode-config` | Mittel |
| W-6 | `project-tools` mischt Zuständigkeiten | Niedrig |
| W-7 | Netz-Allowlist von Tools und `mise.sandbox.toml` getrennt | Niedrig |
| W-8 | README mischt Doku, Testprotokoll und Arbeitsnotizen | Niedrig |
| W-9 | Nicht pinnbare/ungepinnte Versionen (`latest`) | Mittel |
| I-1 | Name per `sed` aus YAML gelesen | Hoch, **erledigt** |
| I-2 | `--name`-Override trennt Sandbox-Name und Historien-Ordner | Mittel, **erledigt** |
| I-3 | Wrapper-Skript statt sbx-Mitteln (`lifecycle`, `mounts`, `host-mount@1`) | Mittel, **teilweise erledigt** |
| I-4 | `shell`-Workload plus `opencode-mixin` statt `agent: opencode` | Frage |
| I-5 | `workload` doppelt: `agent: shell` und `sbx/shell` in `kits` | Niedrig |
| I-6 | `network-policy@1` statt `@2`, `:443`-Suffix mit unklarer Wirkung | Niedrig |
| I-7 | `args` ohne `pattern` für Pfade, `name` ohne `pattern` | Niedrig, **teilweise erledigt** |
| I-8 | Kopie mit `cp -RL` / Rechte der Kopie | Hoch, **erledigt** |
| S-1 | `sbx-env.sh` läuft auf dem Host und ist für den Agenten beschreibbar | Hoch, **teilweise erledigt** |
| S-2 | `kits/` im beschreibbaren Workspace | Mittel |
| S-3 | `git diff` als Prüfmittel ist selbst angreifbar | Mittel |
| S-4 | Credential kann im ganzen API-Host genutzt werden | Mittel |
| S-5 | Deny-all fragt nach, statt hart zu sperren | Mittel |
| S-6 | Host-`AGENTS.md`/Skills landen ungeprüft in der Sandbox | Mittel |
| S-7 | `:latest`-Kits ohne Pinning oder Signatur | Mittel |
| S-8 | Historienverzeichnis mit Standardrechten | Niedrig, **erledigt** |
| S-9 | Workspace enthält `.git` (Hooks) | Mittel |
| S-10 | Docs-Hosts im Runtime-Netz als Abflusskanal | Niedrig |
| S-11 | Bindings sind host-global | Niedrig |

---

## 1. Vollständigkeit

Soll-Ist gegen die Feature-Liste:

| Feature | Stand |
|---|---|
| Einfach aufzusetzen für verschiedene Projekte | Weitgehend. Kopieren, Namen und Tools anpassen. Siehe V-9, W-1. |
| Unterschiedliche Model-Provider | Teilweise. Siehe V-1, V-8. |
| Dev-Tools pro Projekt | Erfüllt über `mise.sandbox.toml`. Rust/Maven fehlen als Beispiel, nur ein Kommentar nennt Hosts. |
| Restriktive Netzfreigabe | Teilweise. Siehe V-6, S-4, S-5, S-10. |
| API-Keys nur außerhalb | Konzeptionell erfüllt (`proxyManaged`, Sentinel). Siehe S-4. |
| Historie außerhalb, überlebt Neuaufsetzen | Umgesetzt, aber nicht belegt. Siehe V-5, I-1, I-2. |
| Dynamische Modellliste | Umgesetzt, aber minimal. Siehe V-2, V-4. |

### V-1 Provider nur OpenAI-kompatibel mit Bearer-Header (Mittel)

`llm-provider.yaml` setzt `header: Authorization` und `format: "Bearer %s"` fest, und das Plugin nutzt `openai-compatible`. Provider mit anderem Schema funktionieren nicht:

- `x-api-key` (native Anthropic-API)
- `api-key` (Azure)
- Gemini-native

Das Feature sagt „unterschiedliche Model-Provider“. Die README sagt zwar „jeder OpenAI-kompatible Provider“, aber das ist eine Einschränkung, die in `features.md` nicht steht.

Empfehlung:
- Kit-Args `authHeader` (Default `Authorization`) und `authFormat` (Default `Bearer %s`) ergänzen.
- Provider-Paket (`package`) ebenfalls als Arg anbieten.
- Die Einschränkung in der README ausdrücklich nennen.

### V-2 Modellliste ohne Filter und ohne Metadaten (Mittel)

- Das Plugin registriert jedes Modell aus `/models` mit `Model.Info.default(...)`.
- Ein Filter fehlt, obwohl `features.md` „die Modelle, die man haben möchte“ nennt. Ein Router wie Requesty liefert sehr viele Modelle, darunter vermutlich auch Embedding- und Bild-Modelle.
- Metadaten (Kontextgröße, Tool-Fähigkeit, Preis) werden nicht übernommen. `default()` liefert nur Platzhalter. [?] Ob Requesty diese Felder in `/v1/models` liefert und wie opencode die Defaults behandelt (Tool-Calling, Limits), ist ungeprüft. Die README bestätigt nur „ansprechbar“.

Empfehlung: Arg `modelFilter` (Glob/Regex auf die ID) oder Allow-/Denylist. Metadaten nach Möglichkeit aus der API-Antwort mappen. Die Modell-Doku zeigt mit `editor.models.update`, wie man Felder nachträgt.

### V-3 Plugin kein eigenständiges Artefakt (Niedrig)

`features.md` nennt „ein Plugin“ als eigenen Bestandteil. Hier existiert es nur als String in `llm-provider.yaml` (Zeilen 80–116) und ist ohne Kit nicht nutzbar oder testbar. Siehe W-4.

### V-4 Plugin ohne Fehlerbehandlung bei Netzfehlern und ohne Refresh (Mittel)

- Bei einem Netzfehler (`fetch` wirft) oder einer unerwarteten Antwort (`body.data` fehlt) wirft `setup`, das Plugin lädt nicht, und es gibt keinen Provider. Nur `!response.ok` ist abgefangen.
- Es gibt kein Timeout (`AbortSignal.timeout`).
- Die Liste wird nur beim Start geholt. Die opencode-Docs zeigen ein Muster mit `provider.reload()` und Intervall. Ohne Refresh bleibt die Liste bis zum Neustart von opencode stehen.
- Kein Fallback: Eine zuletzt gültige Liste wird nicht gecacht, obwohl `ctx.storage` dafür existiert.

### V-5 Historie: Persistenz nicht belegt, SQLite auf Mount offen (Mittel)

- „Geprüft“ in der README enthält nicht, dass eine Session nach `rm` und neuem `run` wieder erscheint. Das ist das Kernfeature.
- [?] Ob `opencode.db` (SQLite mit WAL und `-shm`) auf dem Mount der Sandbox-VM (VM-Dateisystem-Sharing) zuverlässig läuft, ist offen. WAL über geteilte Dateisysteme ist ein bekanntes Problem. Das sollte ausdrücklich getestet werden: schreiben, `rm`, neu erstellen, `opencode session list`.
- Es wird das **gesamte** `~/.local/share/opencode` gemountet. In meiner Umgebung enthält es neben der DB auch `log`, `snapshot`, `tool-output`, `repos`. Das ist für „auswertbar“ in Ordnung, aber die Doku sollte es sagen.

### V-6 Netz „sehr restriktiv“ nur teilweise eingelöst (Mittel)

- Die Hosts des `opencode-mixin` sind nicht aufgelistet („die Hosts, die der opencode-Mixin mitbringt“). [?] Ohne `sbx policy ls` nach dem Erstellen ist die effektive Runtime-Liste nicht bekannt. Das Feature verlangt „gezielt einzelne Endpunkte“.
- Der API-Host ist für alle Methoden und Pfade offen (S-4).
- Siehe S-5 (deny-all fragt nach) und S-10.

Empfehlung: Die effektive Runtime-Allowlist in die README aufnehmen, zum Beispiel als Ausgabe von `sbx policy ls` nach einem Testlauf.

### V-7 Kein Kontext für den Agenten (Niedrig)

Es gibt keine `agent-context`-Capability. Der Agent erfährt nicht, dass das Netz fast ganz gesperrt ist, dass Tools über `mise.sandbox.toml` kommen und dass `apt` und `npm -g` scheitern. Er verschwendet Schritte und versucht Workarounds. Docs: Kits können Anweisungen für den Agenten mitbringen (`agent-context@1`/`@2`, ab sbx 0.45/0.51).

### V-8 Mehrere Provider nicht möglich, nicht dokumentiert (Niedrig)

Das Kit lässt sich wegen Namensgleichheit nicht zweimal einbinden. Docs: „Docker Sandboxes rejects duplicate names in a composition“. Zwei Provider (zum Beispiel Requesty und ein lokales Modell) gehen damit nicht. Das ist legitim, sollte aber in der README stehen.

### V-9 README-Lücken (Niedrig)

- Änderungen an `mise.sandbox.toml` wirken nur beim Erstellen (Install-Hook). Die README sagt nur bei `env:`, dass kein Neuerstellen nötig ist, nicht aber, dass es hier nötig ist (`sbx env rm`, dann `run`). Docs: Kits, Workspaces und Ähnliches wirken nur beim Neuerstellen.
- „Das Verzeichnis kopieren und in die Projektwurzel legen“ ist mehrdeutig. Wegen `workspace: .` wäre bei einer Kopie als Unterordner dieser Unterordner der Workspace, nicht das Projekt. Gemeint sind wohl die Dateien im Projektstamm. Das sollte ausdrücklich stehen.
- „Das Verzeichnis muss als absoluter Pfad im `PATH` stehen“ (Schritt 2) ist unklar. Gemeint ist, dass das Verzeichnis von `op` absolut im `PATH` steht (Docs: Provider-Tools in absoluten `PATH`-Verzeichnissen).
- `name: requesty-test` ist ein Test-Rest im Template.
- Die Vorbedingung `sbx policy init deny-all` ist global für alle Sandboxen und wird vom Skript nicht geprüft.
- `sbx env rm` entfernt die Bindings nicht (S-11).

---

## 2. Wartbarkeit

### W-1 Provider-ID/Host an drei Stellen dupliziert (Mittel)

`id` und `host` stehen in `sbxenv.yaml` als Kit-Args, als `secrets`-Schlüssel (`requesty`) und in `bindings.requesty.apiKey.domains`. Wer den Provider tauscht, muss alle drei synchron ändern. Bei einem Fehler schlägt die Injektion fehl oder es tritt ein Fehler beim Erstellen auf. Das ist fail-closed, aber unfreundlich. Das Kit selbst warnt mit „Dazu `secrets` und `bindings` mit demselben `id` und `host` anlegen“ (README).

Die Env-Args sind laut Docs „anywhere a YAML value can appear“ nutzbar, also auch in Kit-Args und in `domains`-Listen. Ein Env-Arg `llmHost` und `llmId` könnte beide Stellen speisen. Feldnamen (der `secrets`-Schlüssel) lassen sich nicht parametrisieren. Dieser eine Name bleibt manuell.

### W-2 Config-Allowlist dreifach vorhanden (Mittel)

Die Liste `AGENTS.md cli.json agents commands skills themes` steht in `sbx-env.sh` (Zeile 26), in `opencode-config.yaml` (Zeile 25) und in der README. Die Staging-Verzeichnisse **sind** schon die Allowlist. Der Kit-Hook kann daher einfach alles aus dem Mount kopieren (`cp -R "$src"/. "$dst"/`) und braucht keine eigene Liste.

### W-3 Gekoppelte Pfade und Namen (Niedrig)

`/home/agent/.host-config/opencode` steht in `sbxenv.yaml` und im Kit (Kommentar: „target must match“). Dazu kommt `historyDir` in `sbxenv.yaml` und im Skript. Kopplung per Kommentar bricht leicht. Besser: ein Kit-Arg oder die `host-mount@1`-Capability (I-3).

### W-4 Inline-TypeScript und -Shell in YAML (Mittel)

- Das Plugin (37 Zeilen TS) und zwei Shell-Skripte (15 und 20 Zeilen) stehen als Block-Strings in YAML. Es gibt weder Syntax-Highlighting noch Linting (`shellcheck`, `tsc`) noch Tests.
- `${{ kit.args.* }}` wird mitten in Code substituiert. Dadurch lässt sich das TS nicht eigenständig prüfen.
- Prüfen: Die Docs sagen, ein Kit enthalte „its files and descriptor“. Wenn ein lokales Kit-Verzeichnis zusätzliche Dateien aufnehmen kann, wäre das Plugin als echte `.ts`-Datei (und optional als Paket mit `ctx.options`) besser wartbar. [?]

### W-5 `requires` fehlt in `llm-provider` und `opencode-config` (Mittel)

`project-tools` deklariert `requires: ["mise"]`, die anderen beiden nicht, obwohl sie Folgendes brauchen:

- `jq` und `curl` (aus `sbx/shell`)
- das Verzeichnis `~/.config/opencode` und `opencode.json` (aus `opencode-mixin`)

Die Reihenfolge der Hooks hängt daher von der Listenreihenfolge ab. Bei `opencode.json` können zwei Schreiber kollidieren: Der Hook schreibt per `jq … > tmp && mv`, der Mixin schreibt dieselbe Datei. Ein Update kann verloren gehen. Zusätzlich laufen Startup-Hooks laut Capability-Tabelle „alongside the agent“, also parallel zum Start von opencode. [?] Ob dadurch Config-Änderungen vor oder nach dem opencode-Start greifen, ist laut README selbst ungeprüft.

Außerdem prüft `opencode-config` auf `jq` („jq missing“), `llm-provider` nicht. Das Vorgehen ist uneinheitlich.

### W-6 `project-tools` mischt Zuständigkeiten (Niedrig)

Das Kit installiert `libatomic1` (Node-spezifisch) und legt den `vim`-Link an (Basis-Image-Korrektur). Beides hat mit „Projekt-Tools“ wenig zu tun. Pro Projekt muss der Nutzer den ersten Hook ändern (README). Besser: ein getrenntes Kit `base-fixes` und ein `project-tools`, das nur `mise` ausführt.

### W-7 Netz-Allowlist von Tools und `mise.sandbox.toml` getrennt (Niedrig)

Die Download-Hosts in `project-tools.yaml` müssen zu den Tools in `mise.sandbox.toml` passen. Die zwei Dateien liegen in verschiedenen Verzeichnissen, und die Zuordnung steht nur im Kommentar. Alternative: ein Kit-Arg mit kommaseparierter Liste (nur wenn Kit-Args Listen zulassen, [?]) oder pro Sprache ein kleines Kit mit Tools und Hosts zusammen (`kits/tools-java`, `kits/tools-node`). Das passt auch zur Docs-Empfehlung „Keep a tool's requirements in its kit“.

### W-8 README mischt Doku, Testprotokoll und Arbeitsnotizen (Niedrig)

- Die Abschnitte „Geprüft/Ungeprüft“ sind ein Testprotokoll mit Versionsständen (mise 2026.11.0, opencode 2.x). Das veraltet.
- Es enthält Ich-Notizen („die Host-Fassung, die ich gesehen habe“, Zeile 100).
- Der letzte Punkt unter „Ungeprüft“ (`asciidoctor` über npm) ist keine ungeprüfte Sache.
- Die README ist lang. Die Struktur (Aufbau, Vorbereitung, Neues Projekt, Zusammenhänge) ist gut, das Protokoll gehört in eine eigene Datei.

### W-9 Ungepinnte Versionen (Mittel)

`ripgrep`, `pandoc` und `npm:@asciidoctor/cli` stehen auf `latest`. `node = "26"`, `gradle = "9"` und `python = "3.14"` sind nur Major/Minor. Das Ergebnis hängt vom Erstellungstag ab, und Sandboxen für dasselbe Projekt weichen voneinander ab. Zusätzlich sind die Kits `:latest`, siehe S-7. Empfehlung: konkrete Versionen und ein mise-Lockfile (`mise lock`). [?] Ob das mit `MISE_OVERRIDE_CONFIG_FILENAMES` für `mise.sandbox.toml` funktioniert, ist ungeprüft.

---

## 3. Idiomatische Realisierung

### I-1 Name per `sed` aus YAML gelesen (Hoch) [V] — ERLEDIGT

Erledigt in `sbx-env.sh`: `sed` entfernt Anführungszeichen und Kommentar, der Name wird per Regex validiert (`..`, `.`, `/` werden abgelehnt). Mit Stub-`sbx` getestet. Inzwischen abgelöst (I-3): Der Name kommt aus dem Env-Arg `sandboxName` mit `pattern`, das `sed`-Parsen ist entfernt.

`name=$(sed -n 's/^name: *//p' sbxenv.yaml | head -n 1)` versteht kein YAML.

Verifizierte Folgen:

| `name:` in der Datei | Ergebnis |
|---|---|
| `"quoted"  # c` | Verzeichnis heißt wörtlich `"quoted"  # c` (mit Anführungszeichen, Leerzeichen, `#`). |
| `..` | `config_dir` = `$root/.config-stage/..` = `$root`. Der `find … -exec rm -rf` **löscht alle Historien** unter `~/.sbx-history`. In meinem Test war das Verzeichnis danach leer. |
| `../x` | Das Verzeichnis liegt außerhalb von `$root`. |
| `.` | `history_dir` ist `$root` selbst. |

Quotes im Namen sind in YAML üblich. Ein späterer Wechsel zwischen `name: x` und `name: "x"` führt zu einem neuen Ordner, und die Historie scheint verloren.

Empfehlung: Den Namen validieren (`[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]`, ohne `..`), und die Datei nicht mit `sed` parsen (siehe I-3).

### I-2 `--name`-Override trennt Sandbox-Name und Historien-Ordner (Mittel) [V] — ERLEDIGT

Erledigt: Das Skript lehnt `--name` ab (getestet mit Stub-`sbx`). Der Name kommt über `--env-arg sandboxName=<x>` und bestimmt Sandbox und Historien-Ordner gemeinsam.

`sbx env run --name other` benennt die Sandbox um, aber `historyDir` bleibt `…/proj`. Zwei Sandboxen mit verschiedenen `--name` teilen sich so denselben Ordner. Das ist genau der Fall, den die README verbietet („Sandboxen dürfen sich keinen Ordner teilen“, eigene SQLite-DB pro Server). Die Docs nennen `--name` ausdrücklich als Standardflag. Das Skript sollte `--name` auswerten oder ablehnen.

### I-3 Wrapper-Skript statt sbx-Mitteln (Mittel) — TEILWEISE ERLEDIGT

Erledigt: Historien-Ordner anlegen und Config stagen laufen als `lifecycle.initialize` in `sbxenv.yaml`, sichtbar im Plan (auf dem Host bestätigt: der Befehl läuft, die Args sind aufgelöst). Das Skript setzt nur noch `historyRoot` und `hostConfigSrc` aus `$HOME` und ist ortsunabhängig (Arbeitsverzeichnis entscheidet). Offen: `host-mount@1`/`mounts:` sind nicht umgesetzt. Ohne das Skript müsste der absolute `$HOME`-Pfad per `--env-args-file` kommen.

Das Skript erledigt Vorbereitung auf dem Host. Dafür gibt es in sbx eingebaute Wege:

- `lifecycle.initialize`: Host-Befehle in `sbxenv.yaml` (im Workspace-Root schreibgeschützt). Sie erscheinen im Plan, und der Nutzer muss sie genehmigen. Sie erhalten `SBX_SANDBOX_NAME` (der aufgelöste Name inklusive `--name`), `SBX_ENV_DIR` und weitere. Damit entfallen das `sed`-Parsen (I-1, I-2) und die Ungeprüftheit des Skripts (S-1).
- `host-mount@1` und `mounts:` für das Historienverzeichnis (Docs: dafür gibt es `sbx/claude-sessions` und `sbx/codex-sessions`). Beachten: Der von sbx verwaltete Ordner wird per Kit-Quelle geteilt. Für SQLite pro Sandbox muss man also einen eigenen Pfad per `mounts:` angeben.
- Offen [?]: Wie sich damit ein absoluter `$HOME`-Pfad ergeben soll. Die Docs kennen weder `~` noch `$HOME` in `sbxenv.yaml`. Möglichkeiten sind `--env-args-file` oder `~/.sbxenv.yaml`. Das müsste ausprobiert werden.

Das Skript könnte dann entfallen oder stark schrumpfen. Mindestens sollte der `lifecycle`-Weg bewertet werden.

### I-4 `shell`-Workload plus `opencode-mixin` statt `agent: opencode` (Frage)

Die Docs kennen den Weg „Built-in-Agent plus Mixins“ (`agent: opencode`, `kits: [mixins]`). Hier läuft die `shell`-Workload mit überschriebenem Entrypoint (`bash -lc "exec opencode"`). Das hat vermutlich einen Grund, zum Beispiel Login-Shell und PATH. Der Grund steht nirgends. Folgen: agentenspezifisches Verhalten des Built-in-Agents (Sessions, Kontext, Credentials) greift nicht. Das sollte begründet oder umgestellt werden.

### I-5 Workload doppelt (Niedrig)

`agent: shell` löst laut Docs bereits `docker.io/sbx/shell:latest` auf. Zusätzlich steht `docker.io/sbx/shell:latest` in `kits`. Docs: „Avoid adding a kit that's already in the set … can reject the combination.“ [?] Nach Docs-Beispiel (`agent: sbx-kit-claude` plus Workload-Referenz in `kits`) ist das aber ein erlaubtes Muster. Beim Plan prüfen.

### I-6 `network-policy@1` statt `@2`, `:443`-Suffix (Niedrig)

- `@2` erlaubt Begrenzung nach Methode und Pfad (S-4, S-10). Das Kit nutzt `@1`.
- Die Runtime-Einträge tragen `:443`, die Install-Einträge nicht. Laut `@2`-Spec werden „Port suffixes … ignored for allow-list membership“. Der Suffix schränkt vermutlich nichts ein, und die Schreibweise ist uneinheitlich. [?]

### I-7 Args ohne `pattern` (Niedrig) — TEILWEISE ERLEDIGT

Erledigt: Die Args in `sbxenv.yaml` (`sandboxName`, `historyRoot`, `hostConfigSrc`) haben jetzt ein `pattern`. Offen: `name` in `llm-provider.yaml`.

- `sbxenv.yaml`: `historyDir` und `hostConfigDir` haben kein `pattern`, zum Beispiel `^/.+`, obwohl die Docs `pattern` kennen.
- `llm-provider.yaml`: `name` hat kein `pattern` und wird als `"${{ kit.args.name }}"` in den TS-Quelltext gesetzt. Ein `"` im Namen bricht das Plugin. Die Quelle ist die schreibgeschützte `sbxenv.yaml`, daher kein Angriff, aber ein Robustheitsfehler.
- Gut gelöst: Alle Args, die in Shell oder Pfade fließen (`id`, `host`, `basePath`, `envName`, `defaultModel`, `configFile`), haben enge Patterns. Das ist die richtige Praxis.

### I-8 Kopie mit `cp -RL` / Rechte der Kopie (Hoch) [V] — ERLEDIGT

Erledigt: `chmod -R u+w` vor dem Löschen im `initialize`-Befehl von `sbxenv.yaml` (früher in `sbx-env.sh`) und im Hook von `opencode-config.yaml`. Der Befehl lief auf dem Host durch, ein zweiter Lauf bei Nix-verwalteter Config ist nicht ausdrücklich bestätigt. Die Symlink-Dereferenzierung durch `-L` bleibt (siehe S-6).

`cp -RL` übernimmt die Rechtebits der Quelle. Bei schreibgeschützten Quellen, die etwa Nix/Home-Manager erzeugt (Dateien `444`, Verzeichnisse `555`), sind auch Staging-Kopien schreibgeschützt.

Im Test (GNU `cp`, Linux): Der erste Lauf ist erfolgreich. Beim **zweiten Lauf** scheitert `find … -exec rm -rf` mit `Permission denied`, und das Skript beendet sich wegen `set -e` mit Code 1. `./sbx-env.sh run` startet dann nicht mehr.

Auf dem Host ist das System per NixDarwin verwaltet, und `-L` deutet auf Symlinks hin, also ist das wahrscheinlich. [?] macOS-`cp` (BSD) wurde nicht getestet, verhält sich aber bei `-R` ohne `-p` ähnlich.

Dieselbe Falle steckt im Kit-Hook (`cp -R` aus dem Mount nach `~/.config/opencode`, dann beim nächsten Start `rm -rf`). Das ist im Gast ebenfalls anfällig, sobald das Staging schreibgeschützte Rechte trägt.

Behebung: Nach dem Kopieren `chmod -R u+w "$config_dir"`, vor dem Löschen `chmod -R u+w` und dann `rm -rf`. Im Kit `cp -R --no-preserve=mode` (GNU, Debian) oder anschließend `chmod -R u+w`.

Außerdem dereferenziert `-L` Symlinks: Ein Symlink in `skills/` kopiert dessen Ziel mit. Das ist Absicht (Nix), aber auch ein Weg, dass unbeabsichtigt Dateien von außerhalb in die Sandbox gelangen. In meinem Test scheiterte die Kopie von `/etc` genau deshalb mit vielen Fehlern.

---

## 4. Sicherheit

### Was gut gelöst ist

- Der Key liegt nicht in der Sandbox: `proxyManaged: true`, Sentinel in `REQUESTY_API_KEY`, `phase: runtime` (nicht in den Install-Hooks), Injektion nur für `router.eu.requesty.ai`. Das entspricht der Spec („MUST NOT place the real secret in the container“).
- Das Secret kommt per `op://`-Referenz, nicht als Klartext.
- Die Config wird per Allowlist gestaged, `opencode.json` und `plugins/` bleiben draußen, der Mount ist `readOnly`.
- `sbxenv.yaml` liegt im Workspace-Root und ist damit schreibgeschützt (Docs bestätigen das).
- Hook-Args sind per `pattern` begrenzt. Hooks erhalten nur deklarierte Env-Variablen.
- Install-Netz ist nur während des Erstellens offen (Phase `install`).
- Jede Sandbox hat ihre eigene Historie.

### S-1 `sbx-env.sh` läuft auf dem Host und ist für den Agenten beschreibbar (Hoch) [D] — TEILWEISE ERLEDIGT

Erledigt: Die Host-Logik liegt in `lifecycle.initialize` und wird im Plan genehmigt. Das Skript setzt nur noch zwei Env-Args und ist ortsunabhängig, es kann also außerhalb des Workspace liegen. Offen: Es liegt weiterhin im Workspace und läuft ohne Plan. `kits/` bleibt im Workspace (S-2).

Der Workspace ist der Ordner mit `sbxenv.yaml`, also liegen `sbx-env.sh`, `kits/` und `mise.sandbox.toml` im beschreibbaren Mount. Der Agent kann `sbx-env.sh` ändern, und der Nutzer führt es beim nächsten Start **auf dem Host mit seinen Rechten** aus. Es gibt dafür kein Gate und keinen Plan.

Die Docs sagen ausdrücklich: Environment-Dateien und Helfer „outside writable sandbox mounts“ halten. Die README erwähnt das Risiko („Prüfe sie vorher mit `git diff`“), verlässt sich aber auf Disziplin des Nutzers.

Empfehlung (eine von beiden):
- `sbx-env.sh` und `kits/` außerhalb des Workspace ablegen (Projekt-Struktur: `web-app-env/` neben `web-app/`, wie in den Docs).
- Die Host-Logik nach `lifecycle.initialize` in `sbxenv.yaml` verlegen (I-3). Dort erscheint sie im Plan und wird genehmigt.

### S-2 `kits/` im beschreibbaren Workspace (Mittel) [D]

Der Agent kann Kit-Descriptoren ändern, zum Beispiel `network-policy` weiten oder Hooks einfügen. Das wirkt erst beim nächsten Erstellen, und dann sieht der Nutzer das Ergebnis im Plan beziehungsweise im Permission-Gate von sbx. Es braucht trotzdem aufmerksame Prüfung der Plan-Ausgabe. Dieselbe Empfehlung wie S-1: Kits außerhalb des Workspace halten.

### S-3 `git diff` als Prüfmittel ist selbst angreifbar (Mittel)

Die Empfehlung „Prüfe vorher mit `git diff`“ ist unsicher, solange der Agent `.git/config` oder `.gitattributes` schreiben kann (S-9). Dort lassen sich `diff.external`, `textconv` oder Filter setzen, die beim `git diff` auf dem Host Code ausführen, und sie können Änderungen verbergen. Eine Prüfung sollte in einem frischen Klon oder mit `git --no-ext-diff --no-textconv diff` erfolgen. Besser: S-1 beheben.

### S-4 Credential kann im ganzen API-Host genutzt werden (Mittel)

Der Proxy setzt den Key bei **jedem** Request an `router.eu.requesty.ai`. Der Agent (oder ein Prozess in der Sandbox, auch `curl`) kann damit alles aufrufen, was der Key erlaubt: Kosten verursachen, Account-Endpunkte nutzen, Modelle wählen. Das ist bei dem Ansatz nicht ganz vermeidbar.

Empfehlungen:
- `network-policy@2` mit `methods`/`paths` für den API-Host, zum Beispiel nur `/v1/**`, wenn Requesty das zulässt (Spec: Credential-Domain muss in der Allowlist stehen). [?] Die Wirkung auf die Injektion ist ungeprüft.
- Ein dedizierter Key pro Projekt mit Budget-Limit, nicht `Employee/RequestyApiKey` für alles. Das gehört in die README.

### S-5 Deny-all fragt nach, statt hart zu sperren (Mittel) [D]

Nach den Docs wird bei `balanced` und `deny-all` ein Request ohne passende Regel „blocked and asks for your approval“, nicht hart abgelehnt. Die README sagt „Standard ist alles gesperrt“. Wer Rückfragen schnell bestätigt, öffnet das Netz Stück für Stück. Harte Sperren gehen nur über Deny-Regeln. Die Vorbedingung `sbx policy init deny-all` ist außerdem global und wird nicht geprüft. Mindestens sollte die README das genau beschreiben und raten, Rückfragen nie reflexartig zu bestätigen.

### S-6 Host-`AGENTS.md`/Skills landen ungeprüft in der Sandbox (Mittel)

Standardquelle ist die komplette Host-Config (`~/.config/opencode`) mit Allowlist nach Namen, nicht nach Inhalt. Sie enthält zum Beispiel:

- **`AGENTS.md`:** Die des Nutzers sagt „Du nutzt einen Apple Mac… Nie Software installieren, NixDarwin“. Das ist in der Debian-Sandbox falsch und irreführend, und private Hinweise gelangen in die Sandbox und in die Historie.
- **`skills/`, `commands/`, `agents/`:** Sie können Skripte oder interne Hinweise enthalten, die nicht in die Sandbox sollen.
- **Symlinks:** `-L` folgt ihnen und kopiert die Ziele (I-8).

Empfehlung: Standardquelle ist ein eigenes Verzeichnis (zum Beispiel `~/.config/opencode-sandbox`). Die Host-Config wird nur per `SBX_OPENCODE_CONFIG` ausdrücklich freigegeben (Opt-in statt Opt-out).

### S-7 `:latest`-Kits ohne Pinning oder Signatur (Mittel)

`docker.io/sbx/shell:latest`, `…/opencode-mixin:latest` und `…/mise:latest` sind unpinned. Docs: „A latest tag can move to a kit that needs a later sbx release“, und für Reproduzierbarkeit „pin with an immutable tag or digest“. Ein geänderter Mixin kann Netz, Credentials und Hooks ändern, und das ohne Änderung an diesem Repo. Empfehlung: Digest oder feste Version nutzen. Optional `sbx settings set kit.requireSignature true` mit `kit.trustedSigners`.

### S-8 Historienverzeichnis mit Standardrechten (Niedrig) [V] — ERLEDIGT

Erledigt: Der `initialize`-Befehl setzt `umask 077`, die Ordner entstehen mit `700` (im Test bestätigt).

`mkdir -p` legt `~/.sbx-history/<name>` mit `755` an (im Test bestätigt). Die Historie enthält Gesprächsverläufe und Tool-Ausgaben und kann Geheimnisse enthalten. Auf einem Mehrbenutzer-Host wäre sie lesbar. `umask 077` oder `chmod 700` im Skript genügt.

### S-9 Workspace enthält `.git` (Mittel)

`workspace: .` mountet die ganze Projektwurzel schreibbar, auch `.git/hooks` und `.git/config`. Der Agent kann dort Hooks setzen, die beim nächsten `git commit` auf dem Host laufen. Das ist ein generelles Muster bei Sandbox-Agenten. Die Docs bieten den Modus `workspace.clone: true` (privater Klon) als Gegenmittel. Das sollte in der README genannt und bewertet werden, mit Kompromiss (Änderungen kommen nicht direkt ins Arbeitsverzeichnis).

### S-10 Docs-Hosts im Runtime-Netz als Abflusskanal (Niedrig)

`docs.oracle.com`, `docs.gradle.org`, `pandoc.org`, `docs.asciidoctor.org`, `docs.python.org` und `nodejs.org` sind für alle Methoden offen. Über URL-Query oder POST lassen sich dort Daten ablegen (die Betreiber sehen Logs). Die Menge ist klein und der Nutzen für einen Angreifer gering. Für „sehr restriktiv“ wäre `@2` mit `methods: [GET, HEAD]` besser. Gegen Query-Abfluss hilft das aber nicht.

### S-11 Bindings sind host-global (Niedrig) [D]

Laut Docs sind Credential-Bindings global und bleiben nach `sbx env rm` bestehen, außer mit `--prune-bindings`. Der Dienstname `requesty` ist generisch. Die README sollte das nennen. Zusätzlich sollte `rm` im README den Hinweis auf `--prune-bindings` tragen.

---

## Priorisierte Empfehlung

1. ~~**I-8:** Rechte nach dem Kopieren und vor dem Löschen korrigieren (Skript und Kit-Hook). Ohne das startet die Sandbox beim zweiten Mal nicht.~~ Erledigt.
2. **S-1/S-2:** Host-Logik nach `lifecycle.initialize` verlegt (I-3). Skript nur noch dünn, `kits/` weiter im Workspace. Teilweise erledigt, siehe oben.
3. ~~**I-1/I-2:** Den Namen validieren und `--name` berücksichtigen. Das verhindert den Totalverlust der Historien.~~ Erledigt.
4. **S-6:** Dediziertes Config-Verzeichnis als Standard, Host-Config als Opt-in.
5. **W-1/W-2:** Env-Args als einzige Quelle für ID und Host. Allowlist nur im Staging.
6. **V-1/V-2/V-4:** Auth-Header als Arg, Modellfilter, Fehlerbehandlung im Plugin.
7. **W-9/S-7:** Versionen und Kits pinnen.
8. **V-5:** Den Test „Session überlebt `rm` und Neuerstellen“ auf dem Host durchführen und in die README aufnehmen.
9. **S-4/S-5/S-9/V-6:** Netz mit `@2` begrenzen, harte Sperren oder Hinweise zu Rückfragen, `clone`-Modus bewerten, effektive Allowlist dokumentieren.

## Offene Fragen an den Autor

- Warum `shell`-Workload mit überschriebenem Entrypoint statt `agent: opencode` (I-4)?
- Soll die Host-Config Standard oder Opt-in sein (S-6)?
- Reicht ein Provider pro Sandbox (V-8)?
- Sollen Kits und Skript außerhalb des Workspace liegen, auch wenn „Verzeichnis in die Projektwurzel kopieren“ dann nicht mehr gilt (S-1)?

## Auf dem Host zu testen [?]

- Zweiter `./sbx-env.sh run` bei Nix-verwalteter Config (I-8, Fix umgesetzt, noch nicht getestet).
- Session überlebt `rm` und Neuerstellen, SQLite auf dem Mount (V-5).
- Effektive Runtime-Allowlist per `sbx policy ls` (V-6).
- Wirkung von `:443`, ob `@2`-Pfadgrenzen die Key-Injektion beeinflussen (I-6, S-4).
- Doppelte `shell`-Referenz (I-5).
- Metadaten der Requesty-Modelle in opencode (V-2).
- mise-Lockfile mit Override-Dateiname (W-9).
- Reihenfolge der Startup-Hooks und `opencode.json`-Schreibkonflikt (W-5).
