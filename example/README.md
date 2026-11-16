# sbx-Beispiel: opencode mit Requesty

Eine Sandbox mit opencode, Requesty (EU-Router) als Modellquelle und projektspezifischen Dev-Tools.

## Aufbau

```
example/
├── sbxenv.yaml                      # Konfiguration der Sandbox
├── kits/
│   ├── llm-provider/                # Mixin: Credential, Netz, opencode-Plugin
│   │   └── llm-provider.yaml        #   per Kit-Argument auf jeden OpenAI-kompatiblen Provider einstellbar
│   └── project-tools/               # Mixin: installiert projekt/mise.toml beim Erstellen
│       └── project-tools.yaml
├── opencode-history/                # Session-Historie, bleibt beim Neuaufsetzen erhalten
└── projekt/                         # Workspace
    └── mise.toml                    # Dev-Tools dieses Projekts
```

Die Kits haben kein Dockerfile. Alles steht im Descriptor.

| Kit | Herkunft | Aufgabe |
|---|---|---|
| `sbx/shell` | Docker | Basis: Debian, bash, git, agent-User |
| `sbx/opencode-mixin` | Docker | opencode 2.x |
| `sbx/mise-mixin` | Docker | `mise` |
| `kits/project-tools` | hier | `mise install` beim Erstellen, Netz zum Download nur währenddessen |
| `kits/llm-provider` | hier | API-Key-Injection, Freigabe des API-Hosts, Plugin mit dynamischer Modellliste |

## Einmalige Vorbereitung auf dem Host

1. Netzrichtlinie auf „Locked Down“ setzen:
   ```sh
   sbx policy init deny-all
   ```
2. 1Password CLI (`op`) installieren und anmelden. Das Verzeichnis muss als absoluter Pfad im `PATH` stehen.
3. Starten:
   ```sh
   cd example
   sbx env plan
   sbx env run
   ```
4. `sbx env run` startet direkt opencode. Eine Shell gibt es mit `sbx env run -- bash`.

Den Requesty-Key holt sbx aus `op://Employee/RequestyApiKey/password`. Er liegt nicht in der Datei.

## Für ein neues Projekt anpassen

- **Dev-Tools:** `projekt/mise.toml` bearbeiten. Für neue Download-Hosts `install.allow` in `kits/project-tools/project-tools.yaml` ergänzen. Fehlen einem Tool Systembibliotheken (z. B. `libatomic1` für Node), das apt-Paket im ersten Install-Hook ergänzen.
- **Provider:** In `sbxenv.yaml` die `args` des `llm-provider`-Kits setzen. Dazu `secrets` und `bindings` mit demselben `id` und `host` anlegen.

## Was wie zusammenhängt

- **Credential:** Die Sandbox sieht nur einen Platzhalter in `REQUESTY_API_KEY`. Der Host-Proxy setzt den echten Key nur für `router.eu.requesty.ai`.
- **Netz:** Standard ist „alles gesperrt“.
  - Zur Laufzeit erlaubt: der API-Host, die Doku-Hosts und die Hosts, die der opencode-Mixin mitbringt.
  - Die Download-Hosts für die Tools sind nur während `mise install` beim Erstellen offen.
- **Modellliste:** Das Plugin `~/.config/opencode/plugins/requesty.ts` fragt beim Start `/v1/models` ab und registriert den Provider bei opencode.
- **Historie:** `opencode-history/` ist als `~/.local/share/opencode` gemountet.

## Ungeprüft

Diese Punkte habe ich aus der Doku abgeleitet und nicht gegen eine laufende sbx geprüft:

- `${{ kit.args.* }}` in Credential- und Netz-Konfiguration. Die Spec erlaubt das, ein Beispiel dafür gibt es nicht.
- Ob die Download-Hosts in `project-tools` für alle Tools reichen. Bei Fehlern zeigt `sbx policy log` die gesperrten Hosts.
- Ob `mise install` im Install-Hook den Proxy nutzt und ob die Tools danach in der Agent-Shell auf `PATH` liegen.
- Ob opencode das Plugin aus `~/.config/opencode/plugins/` lädt und `@opencode/plugin` dort auflöst.
- `asciidoctor` kommt über `npm:@asciidoctor/cli` (asciidoctor.js), nicht über Ruby.
