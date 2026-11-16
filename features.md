# SBX Kit-Template

Dieses Projekt hilft, eine Docker Sandbox (sbx) basierte Sandbox leicht für ein Projekt aufzubauen.
Ziel ist es, dass mit dieser Grundlage einfach in einem neuen Projekt eine Sandbox eingerichtet werden kann, die einen darin laufenden KI-Agenten absichert.
Als Beispiel nehmen wir den Agenten `opencode`.

Dieses Verzeichnis enthält ein sbx-kit-template, sowie eine Anleitung, wie man es benutzt, und ein Plugin, mit dem opencode leicht auf die Modelle zugreifen kann, die man haben möchte, ohne, dass man sie in der `opencode.json` einzeln erwähnen muss.

## Feature-Übersicht

Das Template, das Plugin und die Anleitung sollten folgendes können:

- einfach aufzusetzen für unterschiedliche Projekte
- nutzbar mit unterschiedlichen KI-Model-Providern
- pro Projekt kann bestimmt werden, welche zusätzlichen Dev-Tools der Agent zur Verfügung hat, neben dem reinen Linux (z. B. node, cargo/rust, jvm, aber auch gradle, maven etc.)
- die Netzwerkfreigabe (auch zu den Model-Providern) sind sehr restriktiv, aus der Sandbox können nur gezielt einzelne Endpunkte erreicht werden.
- API-Keys gibt es nur außerhalb der Sandbox, das Envorinment innerhalb der Sandbox enthält sie nicht
- die opencode-Session-Historie wird außerhalb der Sandbox gehalten, sodass sie auswertbar ist und auch das Neuaufsetzen einer Sandbox überlebt.
- je nach Model-Provider wird die Liste der möglichen LLMs dynamisch erzeugt

