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
| `sbx/shell` | Docker | Basis: Debian, bash, git, agent-User, vim (als `vim.basic`, Link legt `project-tools` an), jq |
| `sbx/opencode-mixin` | Docker | opencode 2.x |
| `sbx/mise` | Docker | `mise` |
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
- **Umgebungsvariablen:** `env:` in `sbxenv.yaml`, z. B. `EDITOR: vim`. Änderungen gelten ab dem nächsten `run`, ohne die Sandbox neu zu erstellen.
- **Dev-Tools:** `mise.sandbox.toml` bearbeiten. Für neue Download-Hosts `install.allow` in `kits/project-tools/project-tools.yaml` ergänzen. Fehlen einem Tool Systembibliotheken (z. B. `libatomic1` für Node), das apt-Paket im ersten Install-Hook ergänzen.
- **Provider:** In `sbxenv.yaml` die `args` des `llm-provider`-Kits setzen. Dazu `secrets` und `bindings` mit demselben `id` und `host` anlegen.

Eine vorhandene `mise.toml` des Projekts wird in der Sandbox ignoriert. Nur `mise.sandbox.toml` zählt.

## Was wie zusammenhängt

- **Credential:** Die Sandbox sieht nur einen Platzhalter in `REQUESTY_API_KEY`. Der Host-Proxy setzt den echten Key nur für `router.eu.requesty.ai`.
- **Netz:** Standard ist „alles gesperrt“.
  - Zur Laufzeit erlaubt: der API-Host, die Doku-Hosts und die Hosts, die der opencode-Mixin mitbringt.
  - Die Download-Hosts für die Tools sind nur während `mise install` beim Erstellen offen.
- **mise:** `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env. mise liest dann nur diese Datei. Der Install-Hook führt einmal `mise trust` für sie aus. Das Docker-Kit `sbx/mise` trägt dagegen `MISE_TRUSTED_CONFIG_PATHS="/"` in die `~/.bashrc` ein. In interaktiven Shells vertraut mise damit jeder Datei im Dateisystem. Das lässt sich hier nicht ändern.
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
- `./sbx-env.sh plan` löst `workspace: .` und die Args `historyDir` und `hostConfigDir` in `additionalWorkspaces.path` auf. Er akzeptiert absolute Pfade außerhalb des Workspaces und `readOnly: true`.
- `jq` ist in der Sandbox installiert.
- `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env (Kit-Arg mit `env:` funktioniert).
- Die Tools aus `mise.sandbox.toml` liegen auf dem `PATH` (Java 21, Node 26).
- `~/.config/opencode/opencode.json` legt `sbx/opencode-mixin` an, nicht unsere Kopie. Der Mixin ergänzt dort nur das MCP-Gateway. Es steht weder `provider.requesty` noch `MODEL_API_KEY` darin.
- `AGENTS.md` aus dem Host landet in der Sandbox. Der Text des Mixins steht nicht in dieser Datei, sondern in `~/.config/opencode/kits-agent-context/opencode-mixin.md`.
- `cli.json` enthält Theme und Keybinds vom Host. Das Feld `plugins` ist entfernt.
- Die Requesty-Modelle erscheinen und sind ansprechbar.
- Das opencode-Plugin lädt laut Log und registriert Provider und Modelle.

## Ungeprüft

- Der Startup-Hook von `kits/opencode-config` läuft vor dem Start von opencode. Die Dateien liegen nach dem Start dort. Ob die TUI beim ersten Start schon Theme und Shortcuts nutzt, ist nicht bestätigt.
- Der Hook überschreibt `cli.json` und die anderen kopierten Einträge bei jedem Start. Der Host ist die Quelle, Einstellungen ändert man dort. Die Sandbox-Datei enthält `session.sidebar: hide`, die Host-Fassung, die ich gesehen habe, nicht. Vermutlich hat die TUI das in der Sandbox geschrieben. Solche Einstellungen gehen beim nächsten Start verloren.
- Ob die Download-Hosts in `project-tools` für alle Tools reichen. Bei Fehlern zeigt `sbx policy log` die gesperrten Hosts.
- `asciidoctor` kommt über `npm:@asciidoctor/cli` (asciidoctor.js), nicht über Ruby.
