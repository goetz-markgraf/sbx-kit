# sbx-Beispiel: opencode mit Requesty

Eine Sandbox mit opencode, Requesty (EU-Router) als Modellquelle und projektspezifischen Dev-Tools. Das Verzeichnis mit `sbxenv.yaml` ist der Workspace.

## Aufbau

```
example/                             # Workspace und Startverzeichnis
├── sbxenv.yaml                      # Konfiguration der Sandbox
├── sbx-env.sh                       # Startskript: Historie, Host-Config, ruft sbx env auf
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
| `sbx/shell` | Docker | Basis: Debian, bash, git, agent-User |
| `sbx/opencode-mixin` | Docker | opencode 2.x |
| `sbx/mise-mixin` | Docker | `mise` |
| `kits/project-tools` | hier | `mise install` beim Erstellen, Netz zum Download nur währenddessen |
| `kits/llm-provider` | hier | API-Key-Injection, Freigabe des API-Hosts, Plugin mit dynamischer Modellliste |
| `kits/opencode-config` | hier | kopiert Shortcuts, Theme, `AGENTS.md`, Skills usw. vom Host in die Sandbox |

## Einmalige Vorbereitung auf dem Host

1. Netzrichtlinie auf „Locked Down“ setzen:
   ```sh
   sbx policy init deny-all
   ```
2. 1Password CLI (`op`) installieren und anmelden. Das Verzeichnis muss als absoluter Pfad im `PATH` stehen.
3. Starten:
   ```sh
   ./sbx-env.sh plan
   ./sbx-env.sh run
   ```
4. `run` startet direkt opencode. Eine Shell gibt es mit `./sbx-env.sh run -- bash`.
5. Entfernen: `./sbx-env.sh rm`. Die Historie bleibt erhalten.

Den Requesty-Key holt sbx aus `op://Employee/RequestyApiKey/password`. Er liegt nicht in der Datei.

## Für ein neues Projekt

Das Verzeichnis kopieren und in die Projektwurzel legen. Dann anpassen:

- **Name:** `name` in `sbxenv.yaml`. Er bestimmt Sandbox und Historie-Ordner.
- **Dev-Tools:** `mise.sandbox.toml` bearbeiten. Für neue Download-Hosts `install.allow` in `kits/project-tools/project-tools.yaml` ergänzen. Fehlen einem Tool Systembibliotheken (z. B. `libatomic1` für Node), das apt-Paket im ersten Install-Hook ergänzen.
- **Provider:** In `sbxenv.yaml` die `args` des `llm-provider`-Kits setzen. Dazu `secrets` und `bindings` mit demselben `id` und `host` anlegen.

Eine vorhandene `mise.toml` des Projekts wird in der Sandbox ignoriert. Nur `mise.sandbox.toml` zählt.

## Was wie zusammenhängt

- **Credential:** Die Sandbox sieht nur einen Platzhalter in `REQUESTY_API_KEY`. Der Host-Proxy setzt den echten Key nur für `router.eu.requesty.ai`.
- **Netz:** Standard ist „alles gesperrt“.
  - Zur Laufzeit erlaubt: der API-Host, die Doku-Hosts und die Hosts, die der opencode-Mixin mitbringt.
  - Die Download-Hosts für die Tools sind nur während `mise install` beim Erstellen offen.
- **mise:** `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env. mise liest dann nur diese Datei. Der Install-Hook führt einmal `mise trust` für sie aus.
- **opencode-Config:** `sbx-env.sh` kopiert aus `~/.config/opencode` nur `AGENTS.md`, `cli.json`, `agents/`, `commands/`, `skills/` und `themes/` nach `~/.sbx-history/.config-stage/<name>/`. Dieser Ordner ist read-only nach `~/.host-config/opencode` gemountet. Das Kit kopiert die Dateien bei jedem Start nach `~/.config/opencode` und überschreibt dabei gleichnamige Einträge. Nicht kopiert werden:
  - `opencode.json`, damit der Host-Provider nicht mit dem Plugin kollidiert und keine Hinweise auf Keys mitkommen.
  - `plugins/`, weil sie Netzfreigaben bräuchten.
  - In `cli.json` fällt `plugins` weg.
  Mit `SBX_OPENCODE_CONFIG` lässt sich ein anderer Quellordner angeben.
- **Modellliste:** Das Plugin `~/.config/opencode/plugins/requesty.ts` fragt beim Start `/v1/models` ab und registriert den Provider bei opencode.
- **Historie:** `~/.sbx-history/<name>/` ist als `~/.local/share/opencode` gemountet. Jede Sandbox hat einen eigenen Ordner, weil jede ihren eigenen opencode-Server mit eigener SQLite-DB startet. Sandboxen dürfen sich keinen Ordner teilen. `sbx` expandiert weder `~` noch `$HOME` in `sbxenv.yaml`. Deshalb übergibt `sbx-env.sh` den Pfad als `historyDir`.

## Schutz der Konfiguration

- `sbxenv.yaml` liegt im Workspace-Root. sbx mountet sie dort schreibgeschützt.
- `kits/`, `mise.sandbox.toml` und `sbx-env.sh` sind für den Agenten schreibbar. Änderungen wirken erst beim nächsten Erstellen der Sandbox. Prüfe sie vorher mit `git diff` und dem Plan von `./sbx-env.sh plan`.

## Geprüft

- mise lädt mit `MISE_OVERRIDE_CONFIG_FILENAMES` nur die genannte Datei (mise 2026.11.0, lokal getestet).
- `mise trust` bleibt nach Änderungen der Datei gültig.
- `workspace: .` meint laut Doku das Verzeichnis der `sbxenv.yaml`.
- Das opencode-Plugin lädt laut Log und registriert Provider und Modelle.

## Ungeprüft

- Kit `opencode-config`:
  - Der Startup-Hook läuft vor dem Start von opencode und vor dem Plugin-Laden.
  - Ein Kit mit ähnlicher Aufgabe liegt in der Sandbox, in der ich gearbeitet habe (`/usr/share/sandbox/kit/spec/kit.yaml`). Es kopiert über einen eigenen Launcher aus `~/opencode-host-config` nach `~/.config/opencode`. Ob `sbx/opencode-mixin` aus `sbxenv.yaml` dasselbe tut, habe ich nicht geprüft. Falls ja, überschreiben sich beide eventuell. Unser Entrypoint ruft `opencode` direkt auf und nicht über diesen Launcher.
  - `jq` ist im Image vorhanden, wurde aber nicht in der echten Sandbox ausgeführt.
- Ob `readOnly: true` bei einem `additionalWorkspaces`-Eintrag mit Zielpfad `~/.host-config/opencode` funktioniert.

- `args` mit `env:` im Kit (`project-tools`). Die Spec erlaubt es, ich habe es nicht in einer laufenden sbx gesehen.
- `${{ env.args.historyDir }}` in `additionalWorkspaces.path`. Die Doku nennt Args für „jeden YAML-Wert“.
- Ob ein absoluter Pfad außerhalb des Workspaces als zusätzlicher Mount akzeptiert wird.
- Ob die Download-Hosts in `project-tools` für alle Tools reichen. Bei Fehlern zeigt `sbx policy log` die gesperrten Hosts.
- Ob die Tools nach `mise install` in der Agent-Shell auf `PATH` liegen.
- `asciidoctor` kommt über `npm:@asciidoctor/cli` (asciidoctor.js), nicht über Ruby.
