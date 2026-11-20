# sbx-Template: opencode in einer Docker Sandbox

Eine Docker Sandbox (`sbx`) für den KI-Agenten opencode. Der Agent läuft abgeschottet:

- Das Netz ist gesperrt. Offen sind nur einzelne Hosts.
- API-Keys liegen nur auf dem Host. Die Sandbox sieht einen Platzhalter.
- Die Session-Historie liegt auf dem Host und übersteht das Neuaufsetzen der Sandbox.
- Jedes Projekt wählt seinen Modell-Provider (jede OpenAI-kompatible API) und seine Dev-Tools selbst.

Das Template ist zweigeteilt: **zentral** im Home-Verzeichnis liegt, was für alle Projekte gleich ist. **Im Projekt** liegen nur zwei Dateien.

> Stand: Die Aufteilung auf Home und Projekt ist noch nie mit `sbx` gelaufen. Was getestet ist und was nicht, steht am Ende unter „Geprüft“ und „Ungeprüft“.

## 1. Aufbau

In diesem Repository simuliert `example_home/` das Home-Verzeichnis (`~`).

```
example_home/                        # simuliert ~
├── .sbxenv.yaml                     # zentrale Defaults für alle Projekte
├── .config/opencode/                # opencode-Config des Hosts (Quelle für cli.json und themes/)
├── .sbx-history/                    # Historie je Sandbox und Config-Stage (nicht im Repo)
└── .sbx-kit/                        # zentrale Kits
    ├── llm-provider/                #   Credential, Netz und Plugin mit Modellliste für einen OpenAI-kompatiblen Provider
    ├── opencode-config/             #   kopiert Theme und Shortcuts vom Host in die Sandbox
    ├── project-tools/               #   installiert mise.sandbox.toml beim Erstellen
    └── requesty-plugin/             #   optional: Budget-Plugin, nur für Requesty

example/                             # ein Projekt: Workspace und Startverzeichnis
├── sbxenv.yaml                      # Name, Provider, Secrets, optionale Kits
└── mise.sandbox.toml                # Dev-Tools dieses Projekts
```

### Wie sbx die Dateien zusammensetzt

Bei `sbx env run` ohne Pfad-Argument führt sbx `~/.sbxenv.yaml` und `./sbxenv.yaml` zusammen:

| Teil | Regel |
|---|---|
| Einzelwerte | Das Projekt überschreibt die Defaults. |
| `args` | Je Name. Das Projekt überschreibt einzelne `default`-Werte. |
| `kits` | Die Listen werden aneinandergehängt. Einträge mit gleicher Quelle führen ihre `args` zusammen. |
| `additionalWorkspaces` | Aneinandergehängt. Gleiches `target` ersetzt den Eintrag. |
| `entrypoint`, `cmd` | Spätere Listen ersetzen frühere. |

`name` darf nur im Projekt stehen. Wer `sbx env` einen Pfad übergibt, überspringt `~/.sbxenv.yaml`. Deshalb immer ohne Pfad aus dem Projektordner starten.

### Was zentral steht

`~/.sbxenv.yaml` enthält:

- den Agent `shell` mit Start von `opencode` (Login-Shell, damit die mise-Tools im `PATH` sind),
- den Workspace `${{ env.projectDir }}`, also das Verzeichnis, aus dem man startet,
- die Basis-Kits und die zentralen Kits,
- den Host-Befehl `lifecycle.initialize`, der Historie-Ordner anlegt und die opencode-Config staged,
- die Mounts für Historie und Config-Stage,
- die generischen Provider-Args (`providerBasePath`, `providerEnvName`) und `EDITOR`.

Es steht dort kein Provider, kein Secret und kein Binding.

### Die Kits

Die Kits haben kein Dockerfile. Alles steht im Descriptor (`<name>.yaml`).

| Kit | Herkunft | Aufgabe |
|---|---|---|
| `sbx/shell` | Docker | Basis: Debian, bash, git, agent-User, vim (als `vim.basic`), jq |
| `sbx/opencode-mixin` | Docker | opencode 2.x |
| `sbx/mise` | Docker | `mise` |
| `project-tools` | zentral | `mise install` beim Erstellen, Download-Netz nur währenddessen, Sandbox-Hinweis für den Agenten |
| `llm-provider` | zentral | Key-Injection und Netzfreigabe für einen Host, Plugin mit dynamischer Modellliste, Default-Modell |
| `opencode-config` | zentral | kopiert `cli.json` und `themes/` vom Host bei jedem Start |
| `requesty-plugin` | optional, im Projekt | Budget und Verbrauch des Requesty-Keys in der opencode-TUI |

## 2. Einmalige Vorbereitung auf dem Host

1. Netzrichtlinie auf „Locked Down“ setzen:
   ```sh
   sbx policy init deny-all
   ```
2. Genehmigung der Host-Befehle merken:
   ```sh
   sbx settings set env.rememberHostCommands true
   ```
   Ohne diese Einstellung verlangt sbx bei jedem `run` eine Genehmigung des Plans, weil `~/.sbxenv.yaml` einen Host-Befehl enthält. Mit ihr fragt sbx nur beim ersten Start und wenn sich der Befehl ändert. Die Einstellung gilt für alle Umgebungen auf dem Host.
3. 1Password CLI (`op`) installieren und anmelden. Das Verzeichnis von `op` muss als absoluter Pfad im `PATH` stehen. Andere Secret-Quellen gehen auch (`command`, `value`, siehe sbx-Doku).
4. Zentrale Dateien ins Home-Verzeichnis legen:
   - `example_home/.sbxenv.yaml` nach `~/.sbxenv.yaml`
   - `example_home/.sbx-kit/` nach `~/.sbx-kit/`
   
   `~/.sbxenv.yaml` darf kein `name` enthalten. Wer opencode auf dem Host nutzt, hat `~/.config/opencode` schon.

## 3. Benutzung: ein Projekt einrichten

Im Projektverzeichnis liegen zwei Dateien. Zum Start `example/` kopieren.

### Checkliste

1. **`sbxenv.yaml` anpassen:**
   - `args.sandboxName.default`: eindeutiger Name. Er bestimmt Sandbox und Historie-Ordner.
   - `providerId`, `providerHost`, optional `providerName` und `providerBasePath` (Default `/v1`).
   - `secrets` und `bindings`: Schlüssel gleich `providerId`, Domain gleich `providerHost`.
2. **`mise.sandbox.toml` anpassen:** die Dev-Tools des Projekts.
3. **Starten:**
   ```sh
   cd <projekt>
   sbx env plan      # prüfen, was passiert
   sbx env run       # Sandbox erstellen und opencode starten
   ```
4. Eine Shell statt opencode: `sbx env run -- bash`. Entfernen: `sbx env rm`. Die Historie bleibt erhalten.

Bei jedem Erstellen kommt die Abfrage „This kit wants to use these credentials“. Sie stammt von `sbx/opencode-mixin`, nicht von unseren Kits. Wir nutzen keinen der dort genannten Dienste, deshalb ist **3 (No)** richtig (Default, ENTER). „Approve all“ ist host-global und wird nicht empfohlen: Ein später gesetzter Key, etwa `sbx secret set github`, würde dann auch in dieser Sandbox injiziert.

### Provider wählen

Es genügt eine OpenAI-kompatible API, die unter `<host><basePath>/models` ihre Modelle auflistet. Das Kit `llm-provider` kennt keinen Provider. `id` und `host` haben keinen Default. Fehlen sie, bricht das Erstellen ab.

Beispiel Requesty (so steht es in `example/sbxenv.yaml`):

```yaml
args:
  providerId:   { default: requesty }
  providerName: { default: Requesty }
  providerHost: { default: router.eu.requesty.ai }

secrets:
  requesty:
    ref: op://Employee/RequestyApiKey/password

bindings:
  requesty:
    apiKey:
      domains: [router.eu.requesty.ai]
```

Beispiel OpenRouter: `providerId: openrouter`, `providerHost: openrouter.ai`, `providerBasePath: /api/v1`. `secrets.openrouter` und `bindings.openrouter` mit Domain `openrouter.ai`.

Map-Schlüssel in `secrets` und `bindings` können keine Args verwenden. Deshalb müssen sie von Hand zu `providerId` passen.

Weitere Provider-Args:

| Arg | Default | Bedeutung |
|---|---|---|
| `providerId` | – | Provider-ID in opencode und Service-Name des Secrets |
| `providerHost` | – | API-Host, einziges Ziel für Key-Injection und Netzfreigabe |
| `providerName` | ID | Anzeigename in opencode |
| `providerBasePath` | `/v1` | Pfad der API auf dem Host |
| `providerEnvName` | `LLM_API_KEY` | Variable mit dem Platzhalter in der Sandbox |
| `defaultModel` | leer | Modell-ID ohne Provider-Präfix. Leer: das erste Modell der Liste, nur solange in `opencode.json` noch keins steht |

### Dev-Tools

`mise.sandbox.toml` im Projekt bearbeiten. Nur diese Datei zählt, eine vorhandene `mise.toml` ignoriert die Sandbox. Tools werden einmal beim Erstellen installiert. Danach braucht die Sandbox keinen Netzzugang dafür.

- **Neuer Download-Host:** Er muss in `install.allow` von `~/.sbx-kit/project-tools/project-tools.yaml` stehen. Das gilt für alle Projekte. `sbx policy log` zeigt gesperrte Hosts.
- **Fehlende Systembibliothek** (z. B. `libatomic1` für Node): das apt-Paket im ersten Install-Hook von `project-tools` ergänzen.
- **Neue Tool-Liste:** Sie wirkt erst nach `sbx env rm` und neuem `run`.

### Weitere Einstellungen im Projekt

- **Umgebungsvariablen:** `env:` in `sbxenv.yaml`, z. B. `JAVA_TOOL_OPTIONS`. Sie gelten ab dem nächsten `run`, ohne neue Sandbox.
- **Requesty-Budget-Plugin:** Das Kit `requesty-plugin` zeigt Budget und Kosten in der TUI (`/requesty`). Im Projekt unter `kits:` eintragen und `secrets` und `bindings` für `requesty-management` (Host `api-v2.requesty.ai`) ergänzen. Projekte ohne Requesty lassen das weg.
  - Args: `version`, `options` (JSON-Objekt für die Plugin-Optionen), `service`, `host`, `envName`.
  - Das Plugin ist ein reines TUI-Plugin und steht deshalb in `~/.config/opencode/cli.json`. Ein erster Install-Hook (als root) übergibt `~/.config/opencode` und `~/.cache/opencode` an den User `agent`. Das ist nötig, weil der Hook des opencode-Mixins dafür erst später läuft. Ohne diesen Schritt scheiterte `plugin add` mit `EACCES`. Der zweite Hook holt das Paket mit `opencode plugin add` und bricht das Erstellen ab, wenn das scheitert. Ein Startup-Hook trägt den Eintrag bei jedem Start erneut ein, weil `opencode-config` die `cli.json` überschreibt.
  - Fehlersuche: `sbx exec <name> -- cat /var/log/sbx-kit-startup.log`, Install-Logs unter `/var/log/sbx-kits`, dazu `opencode plugin list` und `cat ~/.config/opencode/cli.json`.
  - Das Plugin liest `REQUESTY_API_KEY`. Der Modell-Provider nutzt deshalb standardmäßig `LLM_API_KEY`.
  - Der Key braucht die Berechtigung `manage`.
  - Netz: beim Erstellen `registry.npmjs.org`, zur Laufzeit nur `api-v2.requesty.ai`.

### Änderungen wirken wann?

| Änderung | Wirkt |
|---|---|
| `env:` | beim nächsten `run` |
| `entrypoint`, `cmd` | beim nächsten `run` |
| `kits`, `secrets`, `bindings`, Kit-Args, `additionalWorkspaces`, `mise.sandbox.toml` | erst nach `sbx env rm` und neuem `run` |

## 4. Erweitern: eigene Kits

Ein Kit bündelt Tools, Netzfreigaben, Credentials und Startbefehle. Es ist ein Verzeichnis mit einem Descriptor `<verzeichnisname>.yaml`. Das Verzeichnis kann im Projekt oder zentral liegen.

### Wo ein Kit liegt

| Ort | Eintrag in `kits:` | Wann |
|---|---|---|
| **Im Projekt** | `./.sbx/mein-kit` (relativ zur `sbxenv.yaml`) | Nur dieses Projekt braucht es. Es wandert mit dem Projekt ins Git. |
| **Zentral** | `./.sbx-kit/mein-kit` in `~/.sbxenv.yaml` | Alle Projekte brauchen es. Der Agent kann es nicht ändern. |
| **Zentral, optional pro Projekt** | Git-URL oder OCI-Referenz in der Projektdatei | Mehrere Projekte teilen es, aber nicht alle. Beispiel: `requesty-plugin`. |

Warum nicht `~/.sbx-kit/…` in der Projektdatei? sbx expandiert `~` in Env-Dateien nicht. Relative Pfade gehen nur mit `./` oder `../`. Für „zentral und optional“ also Git oder OCI, oder das Kit ins Projekt kopieren.

Das Projekt-Kit wird in `sbxenv.yaml` unter `kits:` eingetragen. Die Liste wird an die zentralen Kits angehängt:

```yaml
kits:
  - ./.sbx/mein-kit
  - source: ./.sbx/anderes-kit
    args:
      flag: wert
  - source: "git+https://github.com/<ORG>/<REPO>.git#ref=<COMMIT>&dir=requesty-plugin"
  - docker.io/<NAMESPACE>/tool:1.0.0
```

Für Git und OCI gilt:

- Quellen außer Docker Hub brauchen `sbx settings set kit.allowedSources '["docker.io/","github.com/<ORG>/"]'`. Die Einstellung ersetzt die ganze Liste.
- Git-Kits mit `ref=<Commit>` und OCI-Kits mit Tag oder Digest festlegen.

### Ein Kit schreiben

Beispiel: ein Projekt-Kit, das `.sbx/postgres-client/postgres-client.yaml` ablegt. Es installiert beim Erstellen ein apt-Paket und gibt zur Laufzeit einen Host frei.

```yaml
# syntax=docker/sandbox-kit:3
schemaVersion: "3"
displayName: Postgres client
description: psql plus egress to the project's dev database.

kind: mixin
version: "1.0.0"

args:
  dbHost:
    required: true
    pattern: '^[a-z0-9.-]+$'
    description: Host of the dev database

capabilities:
  - type: com.docker.sandbox/network-policy@1
    config:
      install:
        allow:
          - deb.debian.org
      runtime:
        allow:
          - ${{ kit.args.dbHost }}:5432

  - type: com.docker.sandbox/lifecycle@1
    config:
      install:
        - command: apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends postgresql-client
          user: "0"
          env: [HTTP_PROXY, HTTPS_PROXY, NO_PROXY, http_proxy, https_proxy, no_proxy]
          description: Install psql
```

Eintrag im Projekt:

```yaml
kits:
  - source: ./.sbx/postgres-client
    args:
      dbHost: db.dev.example.com
```

### Bausteine

| Baustein | Zweck |
|---|---|
| `kind: mixin` | Ergänzt einen Workload (hier `sbx/shell`). Eigene Kits sind fast immer Mixins. |
| `args` | Parameter. Im Descriptor als `${{ kit.args.name }}`. `default` oder `required: true`, dazu `pattern` oder `enum`. Mit `env: NAME` landet der Wert als Variable im Container. |
| `network-policy@1` | `install.allow`: nur während der Install-Hooks offen. `runtime.allow`: dauerhaft. Hosts mit Port, z. B. `host:443`. |
| `credential@1` | Proxy-verwalteter Key: `service`, `phase`, `apiKey.name` (Platzhalter-Variable), `inject` (Domain, Header, Format). Die Domain muss in `network-policy` freigegeben sein. |
| `lifecycle@1` | `install`: einmal beim Erstellen, Netz offen. `startup`: bei jedem Start, muss wiederholbar sein. `files`: schreibt Dateien. Ein Hook sieht nur die in `env` genannten Variablen. |
| `requires`, `provides` | Abhängigkeiten zwischen Kits, z. B. `requires: ["mise"]`, damit `sbx/mise` zuerst läuft. |

Weiter in der sbx-Doku: „Kits“ und die Spezifikation `docker/sandbox-kit-spec`.

### Credentials in eigenen Kits

Ein Kit nennt nur den Service, nie den Key. Zwei Dinge gehören ins Projekt:

1. Das Kit deklariert `credential@1` mit `service: mein-dienst`.
2. Die Projektdatei liefert den Key und die Freigabe:
   ```yaml
   secrets:
     mein-dienst:
       ref: op://Vault/Item/password
   bindings:
     mein-dienst:
       apiKey:
         domains: [api.example.com]
   ```

Pro Service und Phase darf nur ein Kit zuständig sein. Zwei Kits mit demselben Service und derselben Phase sind ein Konflikt.

### Regeln und Fallen

- **Name:** Bei lokalen Kits ist der Verzeichnisname der Kit-Name (der „Handle“ für `--kit-arg`). Er sollte unter allen Kits der Sandbox eindeutig sein. Die sbx-Doku lehnt doppelte Namen ab.
- **Dateipfade:** Zwei Kits dürfen nicht dieselbe Datei in `lifecycle.files` schreiben. Die Spezifikation behandelt das als Konflikt.
- **Variablen:** Zwei Kits sollten nicht dieselbe Umgebungsvariable setzen. Die Spezifikation regelt das nicht ausdrücklich, deshalb nutzt der Provider `LLM_API_KEY` und das Plugin `REQUESTY_API_KEY`.
- **Startup-Hooks:** Sie laufen bei jedem Start und müssen mehrfach laufen können.
- **`cli.json`:** `opencode-config` überschreibt sie bei jedem Start. Es behält die `plugins`, die ein Kit eingetragen hat. Neue Plugin-Kits tragen sich dort im Install-Hook ein, wie `requesty-plugin`.
- **Neues Kit prüfen:** `sbx env plan`, dann eine Sandbox mit anderem `sandboxName` erstellen. Eine vorhandene Sandbox behält ihre Kits.

### Sicherheit bei Projekt-Kits

Ein Kit im Projektverzeichnis ist für den Agenten schreibbar. Er kann es ändern, aber die Änderung wirkt erst beim nächsten Erstellen der Sandbox. Das ist der Unterschied zu zentralen Kits.

- Änderungen an `.sbx/` vor dem Neuerstellen mit `git diff` und `sbx env plan` prüfen.
- Host-Befehle (`lifecycle.initialize`) gehören nicht in Projekt-Kits oder die Projektdatei. Sie stehen nur in `~/.sbxenv.yaml`.
- Eine Netzfreigabe oder ein `credential@1` in einem Projekt-Kit erweitert, was die Sandbox erreichen darf. Der Plan zeigt das.

## 5. Was wie zusammenhängt

- **Credential:** Die Sandbox sieht nur einen Platzhalter in `LLM_API_KEY` (mit dem Plugin-Kit auch in `REQUESTY_API_KEY`). Der Host-Proxy setzt den echten Key nur für den Provider-Host.
- **Netz:** Standard ist „alles gesperrt“.
  - Zur Laufzeit erlaubt: der API-Host, die Doku-Hosts aus `project-tools` und die Hosts des opencode-Mixins.
  - Die Download-Hosts für die Tools sind nur während `mise install` beim Erstellen offen.
- **mise:** `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env, mise liest nur diese Datei. Der Install-Hook führt einmal `mise trust` aus. Das Docker-Kit `sbx/mise` trägt dagegen `MISE_TRUSTED_CONFIG_PATHS="/"` in die `~/.bashrc` ein. In interaktiven Shells vertraut mise damit jeder Datei. Das lässt sich hier nicht ändern.
- **opencode-Config:** Der `initialize`-Befehl kopiert aus `~/.config/opencode` nur `cli.json` und `themes/` nach `~/.sbx-history/.config-stage/<name>/`. Der Ordner ist read-only nach `~/.host-config/opencode` gemountet. `opencode-config` kopiert bei jedem Start nach `~/.config/opencode`. Nicht kopiert werden:
  - `AGENTS.md`, `agents/`, `commands/`, `skills/`: Host-Anweisungen (Mac, Nix usw.) wären in der Sandbox falsch. Das Projekt bringt seine eigenen mit.
  - `opencode.json`: damit der Host-Provider nicht mit dem Plugin kollidiert und keine Key-Hinweise mitkommen.
  - `plugins/`: sie bräuchten Netzfreigaben. In `cli.json` fällt `plugins` weg.
- **Sandbox-Hinweis für den Agenten:** Der letzte Install-Hook von `project-tools` schreibt einen Abschnitt in die globale `~/.config/opencode/AGENTS.md` der Sandbox: eingeschränktes Netz, installierte Tools (`mise ls`). Die `AGENTS.md` des Projekts bleibt unberührt.
- **Modellliste:** Das Plugin `~/.config/opencode/plugins/<providerId>.ts` fragt beim Start `<basePath>/models` ab und registriert Provider und Modelle bei opencode.
- **Historie:** `~/.sbx-history/<name>/` ist als `~/.local/share/opencode` gemountet. Jede Sandbox hat einen eigenen Ordner, weil jede ihren eigenen opencode-Server mit eigener SQLite-DB startet. Sandboxen dürfen sich keinen Ordner teilen. sbx expandiert `~` und `$HOME` nicht, deshalb nutzt `~/.sbxenv.yaml` `${{ env.fileDir }}`, das Verzeichnis der Datei, also das Home-Verzeichnis. Der Name wird als Verzeichnisname benutzt (auch mit `rm -rf`). Das Muster von `sandboxName` schließt `..`, `/` und `'` aus.

## 6. Schutz der Konfiguration

- `~/.sbxenv.yaml` und `~/.sbx-kit/` liegen außerhalb jedes Workspaces. Der Agent kann sie nicht ändern. Das entspricht der Empfehlung der sbx-Doku.
- `sbxenv.yaml` des Projekts liegt im Workspace-Root. sbx mountet sie dort schreibgeschützt. Sie enthält keine Host-Befehle.
- Alle Host-Befehle stehen in `lifecycle.initialize` von `~/.sbxenv.yaml`. Sie erscheinen im Plan und brauchen Zustimmung. Mit `env.rememberHostCommands` fragt sbx nur beim ersten Start und bei jeder Änderung. Den Plan vor dem Bestätigen prüfen.
- `mise.sandbox.toml` und Projekt-Kits sind schreibbar. Änderungen wirken erst beim nächsten Erstellen. Vorher `git diff` und `sbx env plan`.

## Geprüft

Diese Punkte wurden getestet, teils noch mit dem früheren Aufbau in einem einzigen Verzeichnis:

- mise lädt mit `MISE_OVERRIDE_CONFIG_FILENAMES` nur die genannte Datei (mise 2026.11.0).
- `mise trust` bleibt nach Änderungen der Datei gültig.
- Der `initialize`-Befehl (Historie-Ordner anlegen, Config stagen) läuft in `sh` zweimal hintereinander durch, auch bei schreibgeschützter Quelle (Linux, GNU).
- `sbx env plan` löst `workspace: .` und die Pfade der Args in `additionalWorkspaces.path` auf. Er akzeptiert absolute Pfade außerhalb des Workspaces und `readOnly: true`.
- `jq` ist in der Sandbox installiert.
- `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env (Kit-Arg mit `env:` funktioniert).
- Die Tools aus `mise.sandbox.toml` liegen auf dem `PATH` (Java 21, Node 26).
- `~/.config/opencode/opencode.json` legt `sbx/opencode-mixin` an, nicht unsere Kopie. Es steht weder ein Provider-Eintrag noch `MODEL_API_KEY` darin.
- Der Text des Mixins steht in `~/.config/opencode/kits-agent-context/opencode-mixin.md`, nicht in `AGENTS.md`.
- `cli.json` enthält Theme und Keybinds vom Host, `plugins` ist entfernt.
- Die Requesty-Modelle erscheinen und sind ansprechbar. Das opencode-Plugin lädt laut Log und registriert Provider und Modelle.

## Ungeprüft

**Aufteilung auf Home- und Projektdatei** (noch nie in sbx gelaufen):

- ob `name: ${{ env.args.sandboxName }}` im Projekt auf das Arg aus der Home-Datei zeigen kann und die Home-Datei allein gültig ist (sie deklariert `sandboxName` selbst);
- ob das Projekt Defaults der Home-Args mit `default` überschreiben kann;
- ob `secrets`, `bindings`, `env` und `kits` aus beiden Dateien zusammengeführt werden und `secrets` und `bindings` des Projekts ohne zentrale Einträge funktionieren;
- ob relative Kit-Pfade in `~/.sbxenv.yaml` (`./.sbx-kit/...`) vom Home-Verzeichnis aus auflösen und Projekt-Kits (`./.sbx/...`) vom Projekt aus;
- ob Kit-Args wie `"${{ env.args.providerId }}"` aufgelöst werden und Kit-Args beim Zusammenführen gleicher Quellen erhalten bleiben;
- ob `${{ env.fileDir }}` in `lifecycle.initialize` und `additionalWorkspaces.path` auf das Home-Verzeichnis zeigt;
- ob die leeren Defaults von `providerId` und `providerHost` beim Erstellen am Muster des Kits (`required: true`, `^[a-z0-9-]+$`) scheitern;
- ob ein Fehler kommt, wenn der Schlüssel in `secrets` nicht zu `providerId` passt;
- ob `SBX_SANDBOX_NAME` im `initialize`-Befehl bei `--name` vom Arg `sandboxName` abweicht, so dass der Befehl abbricht;
- ob sbx die Patterns der Args im `initialize`-Befehl wie dokumentiert auflöst und der Plan den Befehl anzeigt;
- ob die Rechte `700` des Staging-Ordners dem Mount in der VM nichts verbauen (Lesezugriff des `agent`-Users).

**Kit `requesty-plugin`:**

- ob `opencode plugin add` im Install-Hook jetzt läuft. Bekannt: `opencode` liegt unter `/usr/local/bin/opencode` und war auffindbar. Der erste Versuch scheiterte an den Rechten für `~/.config/opencode` (`EACCES`), wofür es jetzt einen eigenen Hook als root gibt. Nicht erneut getestet: ob npm über den Proxy erreichbar ist und ob das Paket danach im Cache liegt;
- ob das Plugin zur Laufzeit ohne Netz lädt oder opencode beim Start doch npm braucht;
- ob opencode 2 den `cli.json`-Eintrag `{package: "…@2.0.0", options}` akzeptiert (die README des Plugins zeigt `package` ohne Version);
- ob das Plugin den Platzhalter in `REQUESTY_API_KEY` nutzt und `api-v2.requesty.ai` den Proxy-Key akzeptiert;
- ob zwei Services mit demselben Vault-Eintrag (`requesty` und `requesty-management`) funktionieren;
- ob sbx ein Git-Kit mit `#ref=…&dir=…` in der Projektdatei akzeptiert und `kit.allowedSources` dafür reicht.

**Weitere Hooks und Kits:**

- Der Hook mit dem Sandbox-Hinweis in `AGENTS.md`: Der Textblock und die Wiederholung liefen lokal mit einem Stub-`mise`. Offen ist, ob `mise ls --current` das erwartete Format liefert, ob der Hook `~/.config/opencode` schreiben darf und ob der Mixin die Datei später überschreibt. Bei einem Fehler bricht das Erstellen nicht ab, die Datei fehlt dann.
- Der Startup-Hook von `llm-provider`: ob er die Modellliste abrufen kann (Netz im Hook, Proxy-Umgebung, Zertifikat) und `model` einträgt. Bei einem Fehler bleibt die Datei unverändert.
- Der Startup-Hook von `opencode-config` läuft vor dem Start von opencode. Ob die TUI beim ersten Start schon Theme und Shortcuts nutzt, ist nicht bestätigt.
- `opencode-config` überschreibt `cli.json` und `themes/` bei jedem Start. Der Host ist die Quelle. Einstellungen, die die TUI in der Sandbox schreibt (etwa `session.sidebar: hide`), gehen beim nächsten Start verloren.
- Ob die Download-Hosts in `project-tools` für alle Tools reichen. Bei Fehlern zeigt `sbx policy log` die gesperrten Hosts.
- `asciidoctor` kommt über `npm:@asciidoctor/cli` (asciidoctor.js), nicht über Ruby.
- Das Beispiel-Kit `postgres-client` aus Abschnitt 4 ist nur ein Muster und nicht ausgeführt.
