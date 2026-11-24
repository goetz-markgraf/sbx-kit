# sbx-kit: opencode in einer Docker Sandbox – Template

Dieses Template startet den KI-Agenten [opencode](https://opencode.ai) in einer Docker Sandbox (`sbx`). Der Agent ist abgeschottet:

- **Netz gesperrt.** Aus der Sandbox sind nur einzelne Hosts erreichbar.
- **Keine API-Keys in der Sandbox.** Die Keys liegen auf dem Host (z. B. in 1Password). Die Sandbox sieht nur einen Platzhalter. Der Proxy des Hosts setzt den echten Key ein, und nur für den freigegebenen Host.
- **Historie auf dem Host.** Die opencode-Sessions liegen unter `~/.sbx-history/` und überstehen das Neuaufsetzen der Sandbox.
- **Pro Projekt wählbar:** der Modell-Provider (jede OpenAI-kompatible API) und die Dev-Tools (Java, Node, Python, Gradle …).

## 1. So funktioniert es

Die Konfiguration ist zweigeteilt:

- **Zentral** im Home-Verzeichnis liegt, was für alle Projekte gleich ist.
- **Im Projekt** liegen nur zwei Dateien: `sbxenv.yaml` und `mise.sandbox.toml`.

```
~/                                   # Home-Verzeichnis (hier: ./home/)
├── .sbxenv.yaml                     # zentrale Defaults für alle Projekte
├── .config/opencode/                # opencode-Config des Hosts (Theme, Shortcuts)
├── .sbx-history/                    # Historie je Sandbox (entsteht automatisch)
└── .sbx-kit/                        # zentrale Kits
    ├── llm-provider/                #   Modell-Provider: Key, Netz, Modellliste
    ├── opencode-config/             #   Theme und Shortcuts vom Host
    ├── project-tools/               #   Dev-Tools aus mise.sandbox.toml
    └── requesty-plugin/             #   optional: Budget-Anzeige für Requesty

<projekt>/                           # Workspace und Startverzeichnis
├── sbxenv.yaml                      # Name, Provider, Secrets, optionale Kits
└── mise.sandbox.toml                # Dev-Tools dieses Projekts
```

In diesem Repository simuliert `home/` das Home-Verzeichnis und `example/` ist ein (Beispiel-)Projekt.

### Wie sbx beides zusammensetzt

`sbx env run` führt `~/.sbxenv.yaml` und `./sbxenv.yaml` zusammen:


| Teil                         | Regel                                                       |
| ---------------------------- | ----------------------------------------------------------- |
| Einzelwerte                  | Das Projekt überschreibt die Defaults.                      |
| `args`                       | Je Name. Das Projekt überschreibt einzelne `default`-Werte. |
| `kits`                       | Die Listen werden aneinandergehängt.                        |
| `secrets`, `bindings`, `env` | Je Schlüssel zusammengeführt.                               |
| `additionalWorkspaces`       | Aneinandergehängt. Gleiches `target` ersetzt den Eintrag.   |
| `entrypoint`, `cmd`          | Spätere Listen ersetzen frühere.                            |


Zwei Regeln:

- `name` darf nur in `./sbxenv.yaml` (im Projekt) stehen.
- Wer `sbx env` einen Pfad übergibt, überspringt `~/.sbxenv.yaml`. Deshalb immer **ohne Pfad aus dem Projektordner** starten.

### Was zentral steht

`~/.sbxenv.yaml` enthält:

- den Agent `shell`, der `opencode` in einer Login-Shell startet (damit die mise-Tools im `PATH` sind),
- den Workspace `${{ env.projectDir }}`, also das Verzeichnis, aus dem man startet,
- die Liste der globalen Kits, die in jede Sandbox geladen werden sollen,
- einen Host-Befehl (`lifecycle.initialize`), der den Historie-Ordner anlegt und die opencode-Config bereitstellt,
- die Mounts für Historie und Config,
- generische Defaults wie `providerBasePath` und `EDITOR`.

Dort stehen **kein Provider, kein Secret und kein Binding**. Das legt jedes Projekt selbst fest.

### Die Kits

Kits haben kein Dockerfile. Alles steht im Descriptor (`<name>.yaml`).


| Kit                  | Herkunft                          | Aufgabe                                                                                           |
| -------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------- |
| `sbx/shell`          | Docker                            | Basis: Debian, bash, git, Benutzer `agent`, vim, jq                                               |
| `sbx/opencode-mixin` | Docker                            | opencode 2.x                                                                                      |
| `sbx/mise`           | Docker                            | `mise`                                                                                            |
| `project-tools`      | zentral                           | `mise install` beim Erstellen (Download-Netz nur währenddessen), Sandbox-Hinweis für den Agenten  |
| `llm-provider`       | zentral                           | Key-Injection und Netzfreigabe für einen Host, Plugin mit dynamischer Modellliste, Default-Modell |
| `opencode-config`    | zentral                           | kopiert `cli.json` und `themes/` vom Host bei jedem Start                                         |
| `requesty-plugin`    | zentral, **pro Projekt optional** | Budget und Verbrauch des Requesty-Keys in der opencode-TUI                                        |


## 2. Einmalige Einrichtung auf dem Host

1. **Netzrichtlinie** auf „Locked Down“ setzen:
   ```sh
   sbx policy init deny-all
   ```
2. **Host-Befehle merken**, damit sbx nicht bei jedem Start fragt:
   ```sh
   sbx settings set env.rememberHostCommands true
   ```

   Die Befehle in `~/.sbxenv.yaml`, die auf dem Host ausgeführt werden (`initialize`), erscheint im Plan und braucht eine Genehmigung. Mit dieser Einstellung fragt sbx nur beim ersten Start und wenn sich der Befehl ändert. Sie gilt für alle Umgebungen auf dem Host.
3. **1Password CLI** (`op`) installieren und anmelden. Das Verzeichnis von `op` muss als absoluter Pfad im `PATH` stehen. Andere Secret-Quellen gehen auch (`command`, `value`, siehe sbx-Doku).
4. **Zentrale Dateien ins Home-Verzeichnis kopieren:**
   - `home/.sbxenv.yaml` nach `~/.sbxenv.yaml`
   - `home/.sbx-kit/` nach `~/.sbx-kit/`
   
     `~/.sbxenv.yaml` darf kein `name` enthalten.
   - Wer opencode schon auf dem Host nutzt, hat `~/.config/opencode` bereits. Daraus übernimmt die Sandbox nur `cli.json` (Theme, Shortcuts) und `themes/`.

Wenn sich die zentralen Kits ändern: erneut kopieren und die Sandbox neu erstellen (`sbx env rm`, `sbx env run`).

## 3. Ein neues Projekt einrichten

Kopiere `example/sbxenv.yaml` und `example/mise.sandbox.toml` ins Projektverzeichnis und ändere:

### Checkliste

- [ ] **Sandbox-Name:** `args.sandboxName.default`. Er muss eindeutig sein und bestimmt Sandbox und Historie-Ordner. Erlaubt sind Buchstaben, Ziffern und `.`, `_`, `-`.
- [ ] **Provider:** `providerId`, `providerHost` und optional `providerName` und `providerBasePath` (siehe unten).
- [ ] **Secret und Binding:** Der Schlüssel muss gleich `providerId` sein, die Domain gleich `providerHost`. Über diesen Host wird das Secret in den Call injiziert und ist nicht innerhalb der Sandbox sichtbar.
- [ ] **Dev-Tools:** `mise.sandbox.toml`. Hier unter `[tools]` eine Liste der Anwendungen aufnehmen, die in der Sandbox verfügbar sein sollen.
- [ ] **Kits:** Hier können optional lokale Kits eingestellt werden und solche, die aus dem Internet geladen werden. An dieser Stelle können keine kits selektiert werden, die im $HOME-Verzeichnis liegen, denn Umgebungsvariablen und `~` werden nicht aufgelöst.

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

Beispiel OpenRouter: `providerId: openrouter`, `providerHost: openrouter.ai`, `providerBasePath: /api/v1`, dazu `secrets.openrouter` und `bindings.openrouter` mit Domain `openrouter.ai`.

Map-Schlüssel in `secrets` und `bindings` können keine Args verwenden. Deshalb müssen sie von Hand zu `providerId` passen. sbx prüft das nicht und bricht bei einer Abweichung nicht ab (getestet). Ein Tippfehler fällt deshalb nicht beim Erstellen auf. Nach dem Erstellen mit `sbx secret ls` und `sbx env plan` kontrollieren, dass die Namen übereinstimmen.


| Arg                | Default       | Bedeutung                                                                                                                                                 |
| ------------------ | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `providerId`       | –             | Provider-ID in opencode und Service-Name des Secrets                                                                                                      |
| `providerHost`     | –             | API-Host, einziges Ziel für Key-Injection und Netzfreigabe                                                                                                |
| `providerName`     | ID            | Anzeigename in opencode                                                                                                                                   |
| `providerBasePath` | `/v1`         | Pfad der API auf dem Host                                                                                                                                 |
| `providerEnvName`  | `LLM_API_KEY` | Variable mit dem Platzhalter in der Sandbox. Diese enthält nicht selbst das Secret sondern nur einen Platzhalter, der durch sbx beim Aufruf ersetzt wird. |
| `defaultModel`     | leer          | Modell-ID ohne Provider-Präfix. Leer: das erste Modell der Liste, nur solange in `opencode.json` noch keins steht                                         |


### Dev-Tools

`mise.sandbox.toml` im Projekt bearbeiten. Nur diese Datei zählt, eine vorhandene `mise.toml` ignoriert die Sandbox. Die Tools werden einmal beim Erstellen installiert. Danach braucht die Sandbox dafür keinen Netzzugang.

- **Neuer Download-Host:** Er muss in `install.allow` von `~/.sbx-kit/project-tools/project-tools.yaml` stehen. Das gilt für alle Projekte. `sbx policy log` zeigt gesperrte Hosts.
- **Fehlende Systembibliothek** (z. B. `libatomic1` für Node): das apt-Paket im ersten Install-Hook von `project-tools` ergänzen.

### Umgebungsvariablen

`env:` in `sbxenv.yaml`, z. B. `JAVA_TOOL_OPTIONS`. Zentral steht `EDITOR: vim`.

## 4. Im Alltag benutzen

Alle Befehle im Projektverzeichnis, ohne Pfad-Argument:


| Aufgabe                                                      | Befehl                     |
| ------------------------------------------------------------ | -------------------------- |
| Sandbox erstellen und opencode starten, oder wieder anhängen | `sbx env run`              |
| Shell statt opencode                                         | `sbx env run -- bash`      |
| Einen Befehl in der Sandbox ausführen                        | `sbx env exec -- <befehl>` |
| Sandbox entfernen (Historie bleibt)                          | `sbx env rm`               |


Beim ersten Erstellen:

- sbx zeigt den **Plan** (Kits, Mounts, Host-Befehl, Secrets). Prüfe ihn und bestätige.
- Es kommt die Abfrage **„This kit wants to use these credentials“**. Sie stammt von `sbx/opencode-mixin`, nicht von unseren Kits. Wir nutzen keinen der genannten Dienste, deshalb ist **3 (No)** richtig (Default, ENTER). „Approve all“ ist host-global und wird nicht empfohlen: Ein später gesetzter Key, etwa `sbx secret set github`, würde dann auch in dieser Sandbox injiziert.
- Die Warnung „no OpenAI credentials available“ ist harmlos. Wir nutzen den Provider aus der Projektdatei.

### Was wann wirkt


| Änderung                                                                                 | Wirkt                                  |
| ---------------------------------------------------------------------------------------- | -------------------------------------- |
| `env:`, `entrypoint`, `cmd`                                                              | beim nächsten `run`                    |
| `kits`, `secrets`, `bindings`, Kit-Args, Mounts, `mise.sandbox.toml`, Änderungen an Kits | erst nach `sbx env rm` und neuem `run` |


Schlägt das Erstellen fehl, können Teile zurück bleiben (Secrets, halbe Sandbox). Dann immer zuerst `sbx env rm`.

Was `sbx env rm` laut sbx-Doku entfernt: die Sandbox und ihre Secrets (Secrets gelten pro Sandbox). Die Bindings sind host-global und bleiben stehen. Nur `sbx env rm --prune-bindings` löscht sie, und das betrifft auch andere Sandboxen mit denselben Bindings.

## 5. Optional: Requesty-Budget-Plugin

Das Kit `requesty-plugin` zeigt Budget, Monatsverbrauch und Kosten je Modell in der opencode-TUI (Sidebar, Prompt, `/requesty`). Es nutzt das npm-Paket `@christiangalsterer/opencode-requesty-plugin` und ist nur für Projekte mit Requesty gedacht.

Einschalten im Projekt:

```yaml
kits:
  - /Users/<username>/.sbx-kit/requesty-plugin

secrets:
  requesty-management:
    ref: op://<1password-path>

bindings:
  requesty-management:
    apiKey:
      domains: [api-v2.requesty.ai]
```

Mit Plugin-Optionen:

```yaml
kits:
  - source: /Users/<username>/.sbx-kit/requesty-plugin
    args:
      options: '{"sidebar":{"showKeyName":true},"prompt":{"showKeyName":true}}'
```

Hinweise:

- **Absoluter Pfad:** `~`, `$HOME` und `${HOME}` werden in Kit-Pfaden nicht aufgelöst. Es muss der volle Pfad sein. Er enthält deinen Benutzernamen und passt deshalb nicht in ein gemeinsames Projekt. Für ein Team ist eine Veröffentlichung besser (Abschnitt 6, „Ein Kit veröffentlichen“).
- **Eigener Service:** Die Management-API (`api-v2.requesty.ai`) ist ein anderer Host als der Router. Sie hat ein eigenes Secret und Binding. Der Key darf derselbe sein, braucht aber die Berechtigung `manage`.
- **Variablen:** Das Plugin liest `REQUESTY_API_KEY`. Der Modell-Provider nutzt deshalb standardmäßig `LLM_API_KEY`.
- **Args:** `version`, `options` (JSON-Objekt), `service`, `host`, `envName`.
- **Netz:** Beim Erstellen `registry.npmjs.org`, zur Laufzeit nur `api-v2.requesty.ai`.
- **Ohne Requesty:** Kit-Eintrag und die `requesty-management`-Einträge in `secrets` und `bindings` weglassen.

So arbeitet das Kit:

1. Ein Install-Hook (als root) übergibt `~/.config/opencode` und `~/.cache/opencode` an den Benutzer `agent`. Der Hook des opencode-Mixins macht das erst später. Ohne diesen Schritt scheitert `opencode plugin add` mit `EACCES`.
2. Ein zweiter Install-Hook holt das Paket mit `opencode plugin add` und trägt es in `~/.config/opencode/cli.json` ein. Scheitert das, bricht das Erstellen mit Fehlermeldung ab.
3. Ein Startup-Hook trägt den Eintrag bei jedem Start erneut ein, weil `opencode-config` die `cli.json` jedes Mal vom Host neu kopiert.

## 6. Erweitern: eigene Kits

Ein Kit bündelt Tools, Netzfreigaben, Credentials und Startbefehle. Es ist ein Verzeichnis mit einem Descriptor `<verzeichnisname>.yaml`.

### Wo ein Kit liegt


| Ort                               | Eintrag in `kits:`                                                       | Wann                                                                                 |
| --------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| **Im Projekt**                    | `./.sbx/mein-kit` (relativ zur `sbxenv.yaml`)                            | Nur dieses Projekt braucht es. Es wandert mit dem Projekt ins Git.                   |
| **Zentral, für alle**             | `./.sbx-kit/mein-kit`, nutzbar nur in `~/.sbxenv.yaml`                   | Alle Projekte brauchen es. Der Agent kann es nicht ändern.                           |
| **Zentral, pro Projekt optional** | absoluter Pfad `/Users/<username>/.sbx-kit/mein-kit` in der Projektdatei | Nur du nutzt es, aber nicht in jedem Projekt. Beispiel: `requesty-plugin`.           |
| **Geteilt**                       | Git-URL oder OCI-Referenz in der Projektdatei                            | Ein Team teilt es, ohne Benutzernamen im Pfad. Anleitung: „Ein Kit veröffentlichen“. |


Beispiele:

```yaml
kits:
  - ./.sbx/mein-kit
  - source: ./.sbx/anderes-kit
    args:
      flag: wert
  - /Users/<username>/.sbx-kit/requesty-plugin
  - source: "git+https://github.com/<name>/<project>&dir=mein-kit"
  - docker.io/<namespace>/tool:1.0.0
```

Die Liste wird an die zentralen Kits angehängt. Für Git und OCI gilt:

- Quellen außer Docker Hub brauchen `sbx settings set kit.allowedSources '["docker.io/","github.com/<ORG>/"]'`. Die Einstellung ersetzt die ganze Liste.
- Git-Kits mit `ref=<Commit>` und OCI-Kits mit Tag oder Digest festlegen.

Wie ein Kit ohne Benutzernamen im Pfad zu den Projekten kommt, steht im nächsten Abschnitt.

### Ein Kit veröffentlichen (kein Benutzername im Pfad)

Ein absoluter Pfad wie `/Users/<username>/.sbx-kit/requesty-plugin` gehört in kein gemeinsames Projekt. Mit einer Veröffentlichung steht in der Projektdatei stattdessen eine URL oder Referenz, die für alle gleich ist. Es gibt zwei Wege:


|                      | GitHub (Git)                   | Docker Hub (OCI-Image)               |
| -------------------- | ------------------------------ | ------------------------------------ |
| Was liegt dort       | der Quelltext des Kits         | das fertig gebaute Image             |
| Wer baut             | sbx beim Erstellen der Sandbox | du, einmal beim Veröffentlichen      |
| Version festlegen    | Commit oder Tag (`ref=`)       | Tag oder Digest                      |
| Signieren            | nicht möglich                  | `sbx kit sign` und `verify`          |
| `kit.allowedSources` | muss ergänzt werden            | Docker Hub ist schon erlaubt         |
| Voraussetzung        | ein Git-Repository             | ein Docker-Hub-Konto, `docker login` |


Für den Anfang genügt Git. Docker Hub lohnt sich, wenn ihr Signaturen verlangt (`kit.requireSignature`) oder das Kit fertig gebaut verteilen wollt.

Die Kits dieses Templates enthalten keine Secrets, nur Hostnamen und Skripte. Sie dürfen in einem öffentlichen Repository liegen. Secrets bleiben in der Projektdatei und im Vault.

#### Weg 1: GitHub

1. **Repository anlegen.** Jedes Kit ist ein Verzeichnis mit einem Descriptor `<verzeichnisname>.yaml`. Die Verzeichnisse aus `home/.sbx-kit/` können direkt die Wurzel des Repositories sein:
   ```text
   sbx-kits/
   ├── requesty-plugin/requesty-plugin.yaml
   ├── llm-provider/llm-provider.yaml
   ├── opencode-config/opencode-config.yaml
   └── project-tools/project-tools.yaml
   ```
2. **Quelle erlauben**, einmal pro Rechner. Die Einstellung ersetzt die ganze Liste:
   ```sh
   sbx settings set kit.allowedSources '["docker.io/","github.com/<ORG>/"]'
   ```

   Das Muster passt auf Pfadgrenzen. `github.com/<ORG>/` erlaubt die Repositories dieser Organisation, nicht `github.com/<ORG>-andere/`.
3. **Im Projekt eintragen**, mit `dir` für das Kit-Verzeichnis und `ref` für den Commit:
   ```yaml
   kits:
     - "git+https://github.com/<ORG>/sbx-kits.git#ref=<COMMIT>&dir=requesty-plugin"
   ```

   Mit Args:
   
   Die URL steht in Anführungszeichen, weil sie `&` und `#` enthält. `ref` wählt laut Doku eine Revision (Commit, Tag oder Branch). Ein Commit ist unveränderlich und deshalb die sicherere Wahl. Tags und Branches können verschoben werden.
4. **Prüfen:** `sbx env plan` zeigt, welche Quelle sbx verwendet.

Ein privates Repository ist denkbar (`git+ssh://git@github.com/<ORG>/sbx-kits.git#…` ist als Präfix dokumentiert). Wie sbx dabei an die Zugangsdaten kommt, steht in der Doku nicht. Das ist nicht getestet.

#### Weg 2: Docker Hub

1. **Anmelden und veröffentlichen.** Mit Docker Buildx, nicht mit `sbx kit push` (das ist für ältere Kit-Formate):
   ```sh
   docker login
   docker buildx build ./requesty-plugin -f ./requesty-plugin/requesty-plugin.yaml \
       -t docker.io/<NAMESPACE>/requesty-plugin:1.0.0 --push
   ```

   `<NAMESPACE>` ist dein Docker-Hub-Benutzer oder deine Organisation. Für Macs mit Apple Silicon und Linux-Rechner mit Intel zugleich:
   
   Das Image muss in der Registry liegen. Ein Image nur im lokalen Docker reicht nicht.
2. **Im Projekt eintragen:**
   ```yaml
   kits:
     - docker.io/<NAMESPACE>/requesty-plugin:1.0.0
   ```

   Mit Args:
   
   Für eine feste Version statt des Tags den Digest verwenden: `docker.io/<NAMESPACE>/requesty-plugin@sha256:…`. `docker buildx imagetools inspect <referenz>` zeigt ihn.
3. **Privates Repository:** Für Docker Hub nutzt sbx die Anmeldung von `sbx login`. Für andere Registries (z. B. `ghcr.io`) braucht sbx Zugangsdaten: `gh auth token | sbx secret set --registry ghcr.io --password-stdin`.
4. **Optional signieren:** `sbx kit sign docker.io/<NAMESPACE>/requesty-plugin:1.0.0`. Dann `kit.trustedSigners` und `kit.requireSignature` setzen, siehe sbx-Doku.

Der Repository-Name auf Docker Hub ist der Kit-Name. Er sollte zum Verzeichnisnamen passen und unter allen Kits einer Sandbox eindeutig sein.

#### Danach

- **Die zentralen Kits** können genauso aus Git oder Docker Hub kommen. Dann entfällt das Kopieren nach `~/.sbx-kit`, und `~/.sbxenv.yaml` enthält URLs statt `./.sbx-kit/...`. Das ist möglich, aber nicht getestet.
- **Aktualisieren:** Kit ändern, neuen Commit oder Tag veröffentlichen, die Referenz im Projekt anpassen, dann `sbx env rm` und `sbx env run`. Eine bestehende Sandbox behält die Fassung, mit der sie erstellt wurde.
- **Lokal testen,** bevor du veröffentlichst: den Pfad des Kit-Verzeichnisses in `kits:` eintragen. Auf die URL umstellen, wenn es läuft.
- **Vertrauen:** Ein veröffentlichtes Kit läuft bei jedem, der es einträgt, mit Install-Hooks (teils als root) in dessen Sandbox. Das Repository oder die Registry sollte euch gehören. Commit oder Digest festlegen und Änderungen prüfen, bevor die Referenz angehoben wird.
- **Args sind Klartext.** Sie landen im Zustand der Sandbox. Secrets gehören nicht in Kit-Args.

### Ein Kit schreiben

Beispiel: `.sbx/postgres-client/postgres-client.yaml` im Projekt. Das Kit installiert beim Erstellen ein apt-Paket und gibt zur Laufzeit einen Host frei.

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


| Baustein               | Zweck                                                                                                                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind: mixin`          | Ergänzt einen Workload (hier `sbx/shell`). Eigene Kits sind fast immer Mixins.                                                                                               |
| `args`                 | Parameter, im Descriptor als `${{ kit.args.name }}`. `default` oder `required: true`, dazu `pattern` oder `enum`. Mit `env: NAME` landet der Wert als Variable im Container. |
| `network-policy@1`     | `install.allow`: nur während der Install-Hooks offen. `runtime.allow`: dauerhaft. Hosts mit Port, z. B. `host:443`.                                                          |
| `credential@1`         | Proxy-verwalteter Key: `service`, `phase`, `apiKey.name` (Platzhalter-Variable), `inject` (Domain, Header, Format). Die Domain muss in `network-policy` freigegeben sein.    |
| `lifecycle@1`          | `install`: einmal beim Erstellen, Netz offen. `startup`: bei jedem Start. `files`: schreibt Dateien. Ein Hook sieht nur die in `env` genannten Variablen.                    |
| `requires`, `provides` | Abhängigkeiten zwischen Kits, z. B. `requires: ["mise"]`, damit `sbx/mise` zuerst läuft.                                                                                     |


Weiter in der sbx-Doku (Abschnitt „Kits“) und in der Spezifikation `docker/sandbox-kit-spec`.

### Credentials in eigenen Kits

Ein Kit nennt nur den Service, nie den Key:

1. Das Kit deklariert `credential@1` mit `service: mein-dienst`.
2. Die Projektdatei liefert Key und Freigabe:
   ```yaml
   secrets:
     mein-dienst:
       ref: op://Vault/Item/password
   bindings:
     mein-dienst:
       apiKey:
         domains: [api.example.com]
   ```

Pro Service und Phase darf nur ein Kit zuständig sein.

### Regeln und Fallen

- **Hook-Reihenfolge:** Install-Hooks laufen in Kit-Reihenfolge. Der Hook von `sbx/opencode-mixin`, der `~/.config/opencode` an `agent` übergibt, läuft **nach** den Hooks unserer Kits. Ein Kit, das dort schreibt, setzt den Besitzer vorher selbst (siehe `requesty-plugin`).
- **Fehler nicht verschlucken:** Ein Install-Hook mit `exit 0` am Ende meldet immer Erfolg. Bei Dingen, die da sein müssen, den Fehler durchreichen. sbx zeigt dann die Ausgabe des Hooks.
- **Startup-Hooks** laufen bei jedem Start und müssen mehrfach laufen können.
- **`cli.json`:** `opencode-config` überschreibt sie bei jedem Start, behält aber die `plugins`, die ein Kit eingetragen hat. TUI-Plugins gehören dorthin. Plugin-Kits sollten sich im Startup-Hook erneut eintragen.
- **Kit-Name:** Bei lokalen Kits ist der Verzeichnisname der Name. Er sollte unter allen Kits der Sandbox eindeutig sein.
- **Dateien und Variablen:** Zwei Kits dürfen nicht dieselbe Datei in `lifecycle.files` schreiben. Dieselbe Umgebungsvariable zu setzen vermeiden. Deshalb nutzt der Provider `LLM_API_KEY` und das Plugin `REQUESTY_API_KEY`.
- **Änderungen:** Nach Änderungen an einem Kit `sbx env rm` und `sbx env run`. Eine vorhandene Sandbox behält ihre Kits. sbx baut Kit-Images aus lokalen Verzeichnissen nur neu, wenn sich der Inhalt ändert.

### Sicherheit bei Projekt-Kits

Ein Kit im Projektverzeichnis ist für den Agenten schreibbar. Die Änderung wirkt erst beim nächsten Erstellen der Sandbox. Das ist der Unterschied zu zentralen Kits.

- Änderungen an `.sbx/` vor dem Neuerstellen mit `git diff` und `sbx env plan` prüfen.
- Host-Befehle (`lifecycle.initialize`) gehören nicht in Projekt-Kits oder die Projektdatei, sondern nur in `~/.sbxenv.yaml`.
- Eine Netzfreigabe oder ein `credential@1` in einem Projekt-Kit erweitert, was die Sandbox erreichen darf. Der Plan zeigt das.

## 7. Hintergründe

- **Credential:** Die Sandbox sieht nur einen Platzhalter in `LLM_API_KEY` (mit dem Plugin-Kit auch in `REQUESTY_API_KEY`). Der Host-Proxy setzt den echten Key nur für den Provider-Host.
- **Netz:** Standard ist „alles gesperrt“. Zur Laufzeit offen sind der API-Host, die Doku-Hosts aus `project-tools` und die Hosts des opencode-Mixins. Die Download-Hosts für die Tools sind nur während `mise install` beim Erstellen offen.
- **mise:** `MISE_OVERRIDE_CONFIG_FILENAMES=mise.sandbox.toml` steht im Container-Env, mise liest nur diese Datei. Der Install-Hook führt einmal `mise trust` aus. Das Docker-Kit `sbx/mise` trägt dagegen `MISE_TRUSTED_CONFIG_PATHS="/"` in die `~/.bashrc` ein. In interaktiven Shells vertraut mise damit jeder Datei. Das lässt sich hier nicht ändern.
- **opencode-Config:** Der Host-Befehl kopiert aus `~/.config/opencode` nur `cli.json` und `themes/` nach `~/.sbx-history/.config-stage/<name>/`. Der Ordner ist read-only nach `~/.host-config/opencode` gemountet. `opencode-config` kopiert bei jedem Start nach `~/.config/opencode`. Nicht kopiert werden:
  - `AGENTS.md`, `agents/`, `commands/`, `skills/`: Host-Anweisungen (Mac, Nix usw.) wären in der Sandbox falsch. Das Projekt bringt seine eigenen mit.
  - `opencode.json`: damit der Host-Provider nicht mit dem Plugin kollidiert und keine Key-Hinweise mitkommen.
  - `plugins/` und das Feld `plugins` der `cli.json`: Host-Plugins bräuchten Netzfreigaben.
- **Hinweis für den Agenten:** Der letzte Install-Hook von `project-tools` schreibt einen Abschnitt in die globale `~/.config/opencode/AGENTS.md` der Sandbox: eingeschränktes Netz, installierte Tools (`mise ls`). Die `AGENTS.md` des Projekts bleibt unberührt.
- **Modellliste:** Das Plugin `~/.config/opencode/plugins/<providerId>.ts` fragt beim Start `<basePath>/models` ab und registriert Provider und Modelle bei opencode.
- **Historie:** `~/.sbx-history/<name>/` ist als `~/.local/share/opencode` gemountet. Jede Sandbox braucht einen eigenen Ordner, weil jede ihren eigenen opencode-Server mit eigener SQLite-DB startet. sbx expandiert `~` und `$HOME` nicht, deshalb nutzt `~/.sbxenv.yaml` `${{ env.fileDir }}`, das Verzeichnis der Datei, also das Home-Verzeichnis. Der Name wird als Verzeichnisname benutzt (auch mit `rm -rf`). Das Muster von `sandboxName` schließt `..`, `/` und `'` aus.

## 8. Schutz der Konfiguration

- `~/.sbxenv.yaml` und `~/.sbx-kit/` liegen außerhalb jedes Workspaces. Der Agent kann sie nicht ändern. Das entspricht der Empfehlung der sbx-Doku.
- `sbxenv.yaml` des Projekts liegt im Workspace-Root. sbx mountet sie dort schreibgeschützt. Sie enthält keine Host-Befehle.
- Alle Host-Befehle stehen in `lifecycle.initialize` von `~/.sbxenv.yaml`. Sie erscheinen im Plan und brauchen Zustimmung. Den Plan vor dem Bestätigen prüfen.
- `mise.sandbox.toml` und Projekt-Kits sind schreibbar. Änderungen wirken erst beim nächsten Erstellen. Vorher `git diff` und `sbx env plan`.

## 9. Fehlersuche

Auf dem Host:


| Frage                                | Befehl                                                                     |
| ------------------------------------ | -------------------------------------------------------------------------- |
| Was würde sbx tun?                   | `sbx env plan`                                                             |
| Welche Hosts sind gesperrt?          | `sbx policy log`                                                           |
| Was passierte bei den Install-Hooks? | `sbx exec <name> -- sh -c 'ls /var/log/sbx-kits; cat /var/log/sbx-kits/*'` |
| Was passierte beim Start?            | `sbx exec <name> -- cat /var/log/sbx-kit-startup.log`                      |
| Welche Plugins kennt opencode?       | `sbx exec <name> -- opencode plugin list`                                  |
| Was steht in der TUI-Config?         | `sbx exec <name> -- cat /home/agent/.config/opencode/cli.json`             |


Typische Fälle:

- **Das Erstellen bricht ab:** Die Ausgabe nennt den Hook und seine Meldung. Danach `sbx env rm`, Ursache beheben, `sbx env run`.
- **Eine Kit-Änderung wirkt nicht:** Die Sandbox muss neu erstellt werden. Außerdem prüfen, ob die Änderung wirklich in `~/.sbx-kit` angekommen ist. Die Kopie im Repository wird nicht automatisch verwendet.
- **Der Provider zeigt keine Modelle:** `sbx policy log` auf gesperrte Hosts prüfen, und ob `providerId`, `providerHost` und die Schlüssel in `secrets` und `bindings` zusammenpassen.
- **Das Plugin fehlt in der TUI:** `opencode plugin list` und `cli.json` prüfen. Ohne Anzeige trotz Eintrag: Hat der Key die Berechtigung `manage`?
- **Secrets bleiben nach `sbx env rm` stehen, und `sbx secret rm` meldet `-25244` (macOS):** Das ist ein Fehler von sbx 0.54.0. Die Keychain-Einträge stammen aus einer älteren sbx-Version, und die neue Version darf sie nicht ändern ([docker/sbx-releases#899](https://github.com/docker/sbx-releases/issues/899)). Laut Release-Notes behebt sbx 0.54.1 das („secrets saved before an upgrade can be removed without manually deleting their Keychain entries“). Mit `brew update && brew upgrade --cask sbx` aktualisieren, dann `sbx secret rm <service> --sandbox <name>` wiederholen. Das Update ist hier nicht getestet. Bis dahin hilft nur das Löschen des Eintrags mit `security delete-generic-password`. Das Muster des Account-Namens steht im Issue.

## Geprüft

Mit `sbx` auf macOS getestet (Sandbox erstellt, opencode gestartet, Requesty-Modelle und Plugin sichtbar):

- Das Zusammenführen von `~/.sbxenv.yaml` und Projektdatei: `name` aus dem Projekt mit dem Arg `sandboxName`, Provider-Args des Projekts, `secrets` und `bindings` im Projekt, `kits` aus beiden Dateien.
- Absolute Kit-Pfade, in `~/.sbxenv.yaml` und in der Projektdatei. `~`, `$HOME` und `${HOME}` werden dort nicht aufgelöst.
- Kit-Args mit Ausdrücken wie `"${{ env.args.providerId }}"`.
- `${{ env.fileDir }}` zeigt auf das Home-Verzeichnis. Der Host-Befehl legt Historie und Config-Stage an, beide Mounts stimmen.
- `llm-provider`: Provider und Modellliste erscheinen und sind ansprechbar.
- `requesty-plugin`: Paket installiert, in `cli.json` eingetragen, Plugin läuft in der TUI. Erst der Hook als root für die Rechte hat das ermöglicht.
- `project-tools`: Tools aus `mise.sandbox.toml` liegen auf dem `PATH` (Java, Gradle, Node, Python, Pandoc, ripgrep, Asciidoctor).
- `opencode-config`: `cli.json` mit Theme und Keybinds vom Host, ohne Host-Plugins.
- `opencode.json` legt `sbx/opencode-mixin` an. Es steht kein Provider-Eintrag und kein Key darin.
- mise liest mit `MISE_OVERRIDE_CONFIG_FILENAMES` nur die genannte Datei, `mise trust` bleibt nach Änderungen gültig.
- Die Muster der Args in `~/.sbxenv.yaml` und im Kit `requesty-plugin` sind mit `^…$` verankert. Die Sandboxen ließen sich damit neu aufbauen und liefen wie zuvor.
- Der Host-Befehl bricht ab, wenn jemand `--name` statt `--env-arg sandboxName=…` benutzt. Die Fehlermeldung erscheint.
- Bei leerem `providerId` oder `providerHost` bricht das Erstellen mit einer Fehlermeldung ab.
- Ein Schlüssel in `secrets`, der nicht zu `providerId` passt (getestet mit einem umbenannten Schlüssel und mit einer geänderten `providerId`): sbx meldet beim Erstellen **keinen Fehler**. Die Sandbox lief in beiden Fällen weiter. Warum sie trotz der Abweichung funktionierte, ist nicht geklärt (siehe „Noch nicht geprüft“).
- Nach `sbx env rm` standen die Secrets weiter in `sbx secret ls` (Scopes `config`, `requesty-test`, `sbx-kit`). `sbx secret rm` scheiterte mit `-25244`. Das ist ein bekannter Fehler von sbx 0.54.0 auf macOS (siehe Abschnitt 9).

## Noch nicht geprüft

- Relative Projekt-Kits (`./.sbx/...`) und Git- oder OCI-Quellen in der Projektdatei, auch `kit.allowedSources`.
- Das Veröffentlichen (Abschnitt 6): `git+https://…#ref=…&dir=…` als Kit-Quelle, und `docker buildx build` für ein Kit ohne Dockerfile. Laut Spezifikation darf ein Mixin ohne Recipe ein reines Descriptor-Image ergeben. Ein privates Git-Repository und `git+ssh` sind nicht getestet.
- Das Zusammenführen von `secrets`, `bindings` und `env`, wenn sie in beiden Dateien stehen. Die Tabelle in Abschnitt 1 folgt der sbx-Doku (verschachtelte Maps werden je Schlüssel zusammengeführt). Im Beispiel stehen `secrets` und `bindings` nur im Projekt.
- Warum die Sandbox mit einem nicht passenden Schlüssel in `secrets` oder einer abweichenden `providerId` trotzdem funktionierte. Der Test lief mit Secrets aus früheren Läufen im Speicher, und nach dem Löschen wurde er nicht wiederholt. Möglich ist, dass der Proxy über das globale Binding (Domain) zuordnet und nicht über den Service-Namen. Das ist eine Vermutung. Bis zur Klärung gilt die Regel aus Abschnitt 3 weiter, weil sie die sichere Wahl ist.
- Werte, die das Muster von `sandboxName` ausschließen soll, etwa `x/../y` oder `a'; id`: ob sbx sie wirklich ablehnt.
- Ob `sbx env rm` die Secrets der Sandbox entfernt. Der Test lief mit sbx 0.54.0, wo der Fehler `-25244` das Löschen verhindert haben kann. Mit 0.54.1 oder neuer wiederholen.
- Zwei Services (`requesty`, `requesty-management`) mit demselben Vault-Eintrag funktionieren. Die Sandbox lief damit, die Rechte des Keys für die Management-API wurden nicht einzeln geprüft.
- Das Plugin lädt zur Laufzeit ohne Netz aus dem Cache. Es lief, aber ob opencode beim Start doch npm braucht, ist nicht untersucht.
- Der Hinweis in der globalen `AGENTS.md` mit der Tool-Liste: Format von `mise ls --current` und ob der Mixin die Datei später überschreibt.
- Der Startup-Hook von `opencode-config` vor dem Start der TUI: ob Theme und Shortcuts schon beim ersten Start gelten.
- Einstellungen, die die TUI in der Sandbox schreibt (etwa `session.sidebar: hide`), gehen beim nächsten Start verloren, weil der Host die Quelle ist.
- Ob die Download-Hosts in `project-tools` für alle Tools reichen, die jemand ergänzt.
- Das Beispiel-Kit `postgres-client` ist ein Muster und nicht ausgeführt.

## 10. Weitere Informationen:

| Beschreibung | Quelle / Details |
| ---- | ---- |
| Artikel, wie Passwörter mittlerweile abgegriffen werden | https://arstechnica.com/security/2026/11/a-leaky-ai-supply-chain-is-exposing-secret-user-data-at-an-alarming-rate/ |

