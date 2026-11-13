# SBX Opencode -- Features

Dieses Dokument beschreibt, welche Features das Tool `sbx-opencode` haben soll.

## Einsatzzweck

Dieses Tool ist dazu da, möglichst leicht den Agenten `opencode` in einer Docker Sandbox zu betreiben.

## Feature-Übersicht

- einfach aufzusetzen für unterschiedliche Projekte
- nutzbar mit unterschiedlichen KI-Model-Providern
- pro Projekt kann bestimmt werden, welche Dev-Tools der Agent zur Verfügung hat, neben dem reinen Linux
- Netzwerkfreigabe (auch zu den Model-Providern) sind sehr restriktiv
- API-Keys gibt es nur außerhalb der Sandbox. Diese werden durch einen Proxy injiziert. Das gibt nicht nur für die API Keys für die Model, sondern auch für andere Tools, die sich authentifizieren müssen.
- die Session-Historie wird außerhalb der Sandbox gehalten, sodass sie auswertbar ist und auch das Neuaufsetzen einer Sandbox überlebt.
- je nach Model-Provider wird die Liste der möglichen LLMs dynamisch erzeugt
- wenn die Sandbox innerhalb von `tuios` (https://tuios.dev) läuft, ist der Agent darin für tuios sichtbar. Nach Nachrichtensystem von tuios kann zur Kommunikation der Agenten untereinander genutzt werden.

