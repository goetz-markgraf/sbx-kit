# sbx-Beispiel: opencode mit Requesty

Eine Sandbox mit opencode, Requesty (EU-Router) als Modellquelle und projektspezifischen Dev-Tools. Das Verzeichnis mit `sbxenv.yaml` ist der Workspace.

## Aufbau

```
example/                             # Workspace und Startverzeichnis
├── sbxenv.yaml                      # Konfiguration der Sandbox
├── mise.sandbox.toml                # Dev-Tools dieses Projekts
└── kits/
    ├── llm-provider/                # Mixin: Credential, Netz, opencode-Plugin
    │   └── llm-provider.yaml        #   per Kit-Argument auf jeden OpenAI-kompatiblen Provider einstellbar
    ├── opencode-config/             # Mixin: kopiert die opencode-Host-Config in die Sandbox
    │   └── opencode-config.yaml
    └── project-tools/               # Mixin: installiert mise.sandbox.toml beim Erstellen
        └── project-tools.yaml
```

Die Historie liegt nicht im Projekt, sondern auf dem Host unter `~/.sbx-history/<name>/`.

Die Kits haben kein Dockerfile. Alles steht im Descriptor.

| Kit | Herkunft | Aufgabe |
|---|---|---|
| `sbx/shell` | Docker | Basis: Debian, bash, git, agent-User, vim (als `vim.basic`, Link legt `project-tools` an), jq |
| `sbx/opencode-mixin` | Docker | opencode 2.x |
| `sbx/mise` | Docker | `mise` |
| `kits/project-tools` | hier | `mise install` beim Erstellen, Netz zum Download nur währenddessen |
| `kits/llm-provider` | hier | API-Key-Injection, Freigabe des API-Hosts, Plugin mit dynamischer Modellliste |
| `kits/opencode-config` | hier | kopiert Shortcuts, Theme, Skills usw. vom Host in die Sandbox |

## Einmalige Vorbereitung auf dem Host

1. Netzrichtlinie auf „Locked Down“ setzen:
   ```sh
   sbx policy init deny-all
   ```
2. Genehmigung der Host-Befehle merken:
   ```sh
   sbx settings set env.rememberHostCommands true
   ```
   Ohne diese Einstellung verlangt sbx bei jedem `run` eine Genehmigung des Plans, weil `sbxenv.yaml` einen Host-Befehl (`lifecycle.initialize`) enthält. Mit ihr fragt sbx nur beim ersten Start und wenn sich der Befehl ändert. Die Einstellung gilt für alle Umgebungen auf dem Host.
3. 1Password CLI (`op`) installieren und anmelden. Das Verzeichnis von `op` muss als absoluter Pfad im `PATH` stehen.
4. Persönliche Defaults anlegen: `~/.sbxenv.yaml` mit dem absoluten Pfad der Historie. sbx expandiert `~` und `$HOME` in `sbxenv.yaml` nicht, deshalb steht der Pfad hier:
   ```yaml
   schemaVersion: "1"
   args:
     historyRoot:
       default: /Users/<du>/.sbx-history
       pattern: "/[^']+"
   ```
   Fehlt die Datei, bricht sbx ab, weil `historyRoot` nicht deklariert ist. Die Fehlermeldung kommt von sbx und lässt sich aus dem Projekt nicht anpassen. Dann diese Datei anlegen. Wichtig: Wer `sbx env` einen Pfad übergibt, überspringt `~/.sbxenv.yaml`. Immer ohne Pfad aus dem Projektordner starten.
5. Starten:
   ```sh
   sbx env plan
   sbx env run
   ```
   Entscheidend ist das aktuelle Verzeichnis: Es muss `sbxenv.yaml` enthalten.
6. `run` startet direkt opencode. Eine Shell gibt es mit `sbx env run -- bash`.
7. Entfernen: `sbx env rm`. Die Historie bleibt erhalten.

Den Requesty-Key holt sbx aus `op://Employee/RequestyApiKey/password`. Er liegt nicht in der Datei.

## Für ein neues Projekt

Das Verzeichnis kopieren und in die Projektwurzel legen. Dann anpassen:

- **Name:** `sandboxName` (Default der `args` in `sbxenv.yaml`) oder `sbx env run --env-arg sandboxName=<x>`. Er bestimmt Sandbox und Historie-Ordner. `--name` bricht der `initialize`-Befehl ab.
- **Umgebungsvariablen:** `env:` in `sbxenv.yaml`, z. B. `EDITOR: vim`. Änderungen gelten ab dem nächsten `run`, ohne die Sandbox neu zu erstellen.
- **Dev-Tools:** `mise.sandbox.toml` bearbeiten. Für neue Download-Hosts `install.allow` in `kits/project-tools/project-tools.yaml` ergänzen. Fehlen einem Tool Systembibliotheken (z. B. `libatomic1` für Node), das apt-Paket im ersten Install-Hook ergänzen.
- **Provider:** In `sbxenv.yaml` die `args` des `llm-provider`-Kits setzen. Dazu `secrets` und `bindings` mit demselben `id` und `host` anlegen. `defaultModel` ist optional. Ohne Angabe trägt ein Startup-Hook das erste Modell der `/v1/models`-Liste als `model` in `~/.config/opencode/opencode.json` ein, aber nur solange dort noch keins steht. Mit `defaultModel` (ID ohne Provider-Präfix) wählst du ein bestimmtes.

Eine vorhandene `mise.toml` des Projekts wird in der Sandbox ignoriert. Nur `mise.sandbox.toml` zählt.

## Was wie zusammenhängt

- **Credential:** Die Sandbox sieht nur einen Platzhalter in `REQUESTY_API_KEY`. Der Host-Proxy setzt den echten Key nur für `router.eu.requesty.ai`.
- **Abfrage „This kit wants to use these credentials“:** Sie kommt bei jedem Erstellen und stammt von `sbx/opencode-mixin`, nicht von unseren Kits. Der Mixin fragt optional Zugriff auf `anthropic`, `github`, `google`, `groq`, `openai`, `openrouter` und `xai` an. Alle sind „not set“. Der Mixin hat nur das Kit-Arg `version`, die Abfrage lässt sich also nicht per Arg abschalten. Wir nutzen keinen dieser Dienste, deshalb ist **3 (No)** richtig und mit ENTER bestätigt (Default). Der Requesty-Key ist davon unabhängig. Wer die Abfrage loswerden will, kann einmal „Approve all“ wählen (gilt host-global in `~/.config/sbx/credentials.yaml`). Das wird hier nicht empfohlen: Ein später gesetzter Key, etwa `sbx secret set github`, würde dann auch in dieser Sandbox injiziert.
- **Netz:** Standard ist „alles gesperrt“.
  - Zur Laufzeit erlaubt: der API-Host, die Doku-Hosts und die Hosts, die der opencode-Mixin mitbringt.
  - Die Download-Hosts für die Tools sind nur während `mise install` beim Erstellen offen.
- **mise:** `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env. mise liest dann nur diese Datei. Der Install-Hook führt einmal `mise trust` für sie aus. Das Docker-Kit `sbx/mise` trägt dagegen `MISE_TRUSTED_CONFIG_PATHS="/"` in die `~/.bashrc` ein. In interaktiven Shells vertraut mise damit jeder Datei im Dateisystem. Das lässt sich hier nicht ändern.
- **opencode-Config:** Der `initialize`-Befehl in `sbxenv.yaml` kopiert aus `~/.config/opencode` nur `cli.json` und `themes/` nach `~/.sbx-history/.config-stage/<name>/`. Dieser Ordner ist read-only nach `~/.host-config/opencode` gemountet. Das Kit kopiert die Dateien bei jedem Start nach `~/.config/opencode` und überschreibt dabei gleichnamige Einträge. Nicht kopiert werden:
  - `AGENTS.md`, `agents/`, `commands/` und `skills/`, weil Host-Anweisungen (Mac, Nix usw.) und Skripte in der Sandbox falsch oder unerwünscht wären. Das Projekt bringt seine eigenen mit.
  - `opencode.json`, damit der Host-Provider nicht mit dem Plugin kollidiert und keine Hinweise auf Keys mitkommen.
  - `plugins/`, weil sie Netzfreigaben bräuchten.
  - In `cli.json` fällt `plugins` weg.
- **Sandbox-Hinweis für den Agenten:** Der letzte Install-Hook von `kits/project-tools` schreibt nach dem `mise install` einen Abschnitt in die globale `~/.config/opencode/AGENTS.md` der Sandbox. Er sagt, dass der Agent in einer Sandbox mit eingeschränktem Netz läuft, und listet die installierten Tools (`mise ls`, also die tatsächlich installierten Versionen aus `mise.sandbox.toml`). Die `AGENTS.md` des Projekts bleibt unberührt, opencode liest beide. Der Text steht im Hook und lässt sich dort anpassen.
- **Modellliste:** Das Plugin `~/.config/opencode/plugins/requesty.ts` fragt beim Start `/v1/models` ab und registriert den Provider bei opencode.
- **Historie:** `~/.sbx-history/<name>/` ist als `~/.local/share/opencode` gemountet. Jede Sandbox hat einen eigenen Ordner, weil jede ihren eigenen opencode-Server mit eigener SQLite-DB startet. Sandboxen dürfen sich keinen Ordner teilen. `sbx` expandiert weder `~` noch `$HOME` in `sbxenv.yaml`. Deshalb steht `historyRoot` in `~/.sbxenv.yaml`. Anlegen und Befüllen der Ordner macht der `initialize`-Befehl (Historie-Ordner mit Rechten `700`).

## Schutz der Konfiguration

- `sbxenv.yaml` liegt im Workspace-Root. sbx mountet sie dort schreibgeschützt.
- Alle Host-Befehle stehen in `lifecycle.initialize` von `sbxenv.yaml`. Sie erscheinen im Plan und brauchen deine Zustimmung. Mit `env.rememberHostCommands` (siehe Vorbereitung) fragt sbx nur beim ersten Start und bei jeder Änderung des Befehls. Prüfe den Plan vor dem Bestätigen.
- `kits/` und `mise.sandbox.toml` sind schreibbar. Änderungen wirken erst beim nächsten Erstellen der Sandbox. Prüfe sie vorher mit `git diff` und dem Plan von `sbx env plan`.

## Geprüft

- mise lädt mit `MISE_OVERRIDE_CONFIG_FILENAMES` nur die genannte Datei (mise 2026.11.0, lokal getestet).
- `mise trust` bleibt nach Änderungen der Datei gültig.
- Der `initialize`-Befehl (Historie-Ordner anlegen, Config stagen) läuft in `sh` zweimal hintereinander durch, auch bei schreibgeschützter Quelle (Linux, GNU, lokal getestet).
- `sbx env plan` löst `workspace: .` und die Pfade der Args in `additionalWorkspaces.path` auf. Er akzeptiert absolute Pfade außerhalb des Workspaces und `readOnly: true`. (Vor der Umstellung auf `initialize` getestet, nicht erneut.)
- `jq` ist in der Sandbox installiert.
- `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env (Kit-Arg mit `env:` funktioniert).
- Die Tools aus `mise.sandbox.toml` liegen auf dem `PATH` (Java 21, Node 26).
- `~/.config/opencode/opencode.json` legt `sbx/opencode-mixin` an, nicht unsere Kopie. Der Mixin ergänzt dort nur das MCP-Gateway. Es steht weder `provider.requesty` noch `MODEL_API_KEY` darin.
- Die Host-`AGENTS.md`, `agents/`, `commands/` und `skills/` werden nicht mehr gestaged (nicht erneut getestet). Der Text des Mixins steht nicht in dieser Datei, sondern in `~/.config/opencode/kits-agent-context/opencode-mixin.md`.
- `cli.json` enthält Theme und Keybinds vom Host. Das Feld `plugins` ist entfernt.
- Die Requesty-Modelle erscheinen und sind ansprechbar.
- Das opencode-Plugin lädt laut Log und registriert Provider und Modelle.

## Ungeprüft

- Der Hook, der die globale `AGENTS.md` mit Sandbox-Hinweis und Tool-Liste schreibt: Der Textblock und die Wiederholung wurden lokal mit einem Stub-`mise` getestet. In der Sandbox ist offen, ob `mise ls --current` das erwartete Format liefert, ob der Hook das Verzeichnis `~/.config/opencode` schreiben darf (der opencode-Mixin setzt dessen Besitzer in einem eigenen Hook) und ob der Mixin die Datei später überschreibt. Schlägt das Schreiben fehl, bricht der Hook das Erstellen nicht ab. Die Datei fehlt dann.
- Die Umstellung auf `~/.sbxenv.yaml` (ohne Wrapper-Skript): ob `args` aus der Home-Datei mit den `args` im Projekt zusammengeführt werden, `${{ env.args.historyRoot }}` darin aufgelöst wird und was sbx ausgibt, wenn die Datei fehlt. Außerdem, ob `SBX_SANDBOX_NAME` im `initialize`-Befehl bei `--name` vom Arg `sandboxName` abweicht, so dass der Befehl abbricht.
- Der neue `lifecycle.initialize`-Block: ob sbx `${{ env.args.* }}` und die Patterns darin wie dokumentiert auflöst, `name: ${{ env.args.sandboxName }}` funktioniert und der Plan den Befehl anzeigt. Der Befehl läuft ohne sbx nur als Shell-Test.
- Ob die Rechte `700` des Staging-Ordners dem Mount in der VM nichts verbauen (Lesezugriff des `agent`-Users).
- Das Startmodell: Ob der Startup-Hook von `llm-provider` die Modellliste abruft (Netz im Hook, Proxy-Umgebung, Zertifikat) und `model` in `opencode.json` einträgt. Schlägt der Abruf fehl, meldet der Hook das und lässt die Datei unverändert.
- Der Startup-Hook von `kits/opencode-config` läuft vor dem Start von opencode. Die Dateien liegen nach dem Start dort. Ob die TUI beim ersten Start schon Theme und Shortcuts nutzt, ist nicht bestätigt.
- Der Hook überschreibt `cli.json` und die anderen kopierten Einträge bei jedem Start. Der Host ist die Quelle, Einstellungen ändert man dort. Die Sandbox-Datei enthält `session.sidebar: hide`, die Host-Fassung, die ich gesehen habe, nicht. Vermutlich hat die TUI das in der Sandbox geschrieben. Solche Einstellungen gehen beim nächsten Start verloren.
- Ob die Download-Hosts in `project-tools` für alle Tools reichen. Bei Fehlern zeigt `sbx policy log` die gesperrten Hosts.
- `asciidoctor` kommt über `npm:@asciidoctor/cli` (asciidoctor.js), nicht über Ruby.
