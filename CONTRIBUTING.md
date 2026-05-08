# Zasady współpracy — macOSTeam

Dokument definiuje obowiązujące standardy pracy w projekcie.
Każde odstępstwo od poniższych zasad podlega procedurze eskalacji.

---

## Spis treści

1. [Filozofia projektu](#filozofia-projektu)
2. [Struktura gałęzi](#struktura-gałęzi)
3. [Konwencja commitów](#konwencja-commitów)
4. [Pull Requesty](#pull-requesty)
5. [Standardy jakości](#standardy-jakości)
6. [GitHub Projects — zarządzanie zadaniami](#github-projects--zarządzanie-zadaniami)
7. [Procedury eskalacji](#procedury-eskalacji)
8. [Praca z agentami AI](#praca-z-agentami-ai)

---

## Filozofia projektu

- **Atomowość** — każdy commit, PR i subtask realizuje dokładnie jedną logiczną zmianę.
- **Czytelność** — kod i dokumentacja mają być zrozumiałe dla człowieka, nie dla maszyny.
- **Odwracalność** — każda zmiana powinna być możliwa do cofnięcia bez skutków ubocznych.
- **Transparentność** — decyzje techniczne są uzasadniane w opisach PR lub dokumentacji.

---

## Struktura gałęzi

```
main          — produkcyjna, stabilna; merge tylko przez PR z approved review
develop       — integracja; baza dla wszystkich gałęzi roboczych
  │
  ├─ feature/STORY-XXX-krotki-opis     — nowa funkcjonalność
  ├─ fix/STORY-XXX-krotki-opis         — naprawa błędu
  ├─ ops/STORY-XXX-krotki-opis         — infrastruktura, hooki, konfiguracja
  ├─ docs/STORY-XXX-krotki-opis        — wyłącznie dokumentacja
  └─ agent/STORY-XXX-krotki-opis       — praca autonomicznego subagenta AI
```

**Zasady:**
- Gałęzie robocze tworzymy zawsze od `develop`, nigdy od `main`.
- Nazwa gałęzi zawiera numer Story z GitHub Projects.
- Gałęzie `main` i `develop` są chronione — push bezpośredni jest zablokowany.

---

## Konwencja commitów

Format: **Conventional Commits** — wszystko po polsku.

```
<typ>(zakres): krótki opis w trybie dokonanym

[opcjonalne rozwinięcie — co i dlaczego]

[opcjonalne: Refs #numer-issue]
```

### Typy commitów

| Typ       | Kiedy używać                                              |
|-----------|-----------------------------------------------------------|
| `feat`    | Nowa funkcjonalność                                       |
| `fix`     | Naprawa błędu                                             |
| `ops`     | Hooki, konfiguracja, infrastruktura bez wpływu na logikę |
| `docs`    | Wyłącznie dokumentacja                                    |
| `refactor`| Zmiana kodu bez zmiany zachowania                         |
| `test`    | Dodanie lub poprawa testów                                |
| `chore`   | Porządki, aktualizacje zależności                         |
| `agent`   | Commit wygenerowany autonomicznie przez subagenta AI      |

### Przykłady

```
feat(mcp): dodano serwer wiedzy zespołu z obsługą SQLite

Serwer FastMCP udostępnia 4 narzędzia: report_observation,
get_knowledge_context, report_violation, promote_knowledge.
Dane trwałe w /workspace/mcp/data/knowledge.db.

Refs #12
```

```
ops(hooki): zastąpiono watchdog_snapshot pushami macOS

Zamiast archiwów tar.gz katalogu użytkownika — powiadomienia
systemowe z poziomami eskalacji. Wyciszono szum przy normalnej pracy.

Refs #15
```

**Zasady:**
- Opis w trybie dokonanym: „dodano", „naprawiono", „zastąpiono" — nie „dodaje", „dodać".
- Maksymalnie 72 znaki w pierwszej linii.
- Rozwinięcie wyjaśnia **dlaczego**, nie **co** (to widać w diffie).
- Jeden commit = jedna logiczna zmiana. Squash przed mergem jeśli potrzeba.

---

## Pull Requesty

### Struktura opisu PR

```markdown
## Co zostało zrealizowane
[1-3 zdania opisujące zmianę]

## Dlaczego
[uzasadnienie — kontekst biznesowy lub techniczny]

## Jak testować
- [ ] krok 1
- [ ] krok 2

## Powiązane
Refs #numer-story
```

### Zasady

- Każdy PR jest powiązany z co najmniej jednym Issue / Story w GitHub Projects.
- PR nie może zawierać zmian niezwiązanych z opisanym zadaniem.
- PR wymaga przeglądu (review) przed mergem do `develop`.
- Merge do `main` wymaga przeglądu i zatwierdzonego statusu CI.
- Tytuł PR zaczyna się od numeru Story: `[STORY-XXX] Krótki opis`.
- PR bez przypisanego Issue zostanie zamknięty bez review.

---

## Standardy jakości

### Kod

- Każda zmiana logiki posiada testy lub jawne uzasadnienie ich braku w opisie PR.
- Brak kodu debugującego (`print`, `console.log`, tymczasowe komentarze).
- Skrypty shell: `set -euo pipefail` na początku każdego pliku.
- Python: zgodność z PEP 8, brak `eval()` na danych zewnętrznych.

### Komentarze w kodzie

- Komentarze opisują **dlaczego**, nie **co**.
- Komentarze procesowe (dlaczego tak, a nie inaczej) — po polsku.
- Brak komentarzy opisujących oczywiste działanie kodu.

### Dokumentacja

- Każde nowe narzędzie lub hook posiada opis wywołania w nagłówku pliku.
- Zmiany w architekturze są odnotowywane w `docs/`.

---

## GitHub Projects — zarządzanie zadaniami

### Struktura

```
EPIC → STORY → SUBTASK (Issue)
```

- **EPIC** — duży obszar funkcjonalny (np. „System powiadomień macOS")
- **STORY** — samodzielna, dostarczona wartość (np. „Powiadomienia eskalacyjne")
- **SUBTASK** — atomowe zadanie implementacyjne przypisane do jednego PR

### Kolumny tablicy

| Kolumna      | Znaczenie                                        |
|--------------|--------------------------------------------------|
| `Backlog`    | Zidentyfikowane, niezaplanowane                  |
| `Planned`    | Zaplanowane na bieżący sprint                    |
| `In Progress`| Aktualnie realizowane                            |
| `Review`     | Czeka na code review                             |
| `Done`       | Zmerge'owane do `develop`                        |

### Zasady

- Każdy SUBTASK to jeden Issue na GitHubie z przypisanym PR.
- Status Issues jest aktualizowany na bieżąco — nie po fakcie.
- Opis każdego Issue zawiera kryteria akceptacji (Definition of Done).
- Agent AI aktualizuje status Issue przy starcie i zakończeniu pracy.

---

## Procedury eskalacji

Naruszenia zasad są rejestrowane przez system watchdog i powiadamiają użytkownika.

### Poziomy naruszeń

| Poziom     | Przykłady naruszeń                                              | Reakcja systemu                          |
|------------|-----------------------------------------------------------------|------------------------------------------|
| `minor`    | Brak opisu PR, commit bez typu, niezaktualizowany status Issue  | Wpis w dzienniku, push info              |
| `major`    | Merge bez review, commit do `main` bezpośrednio, brak testów   | Push eskalacja1, wpis CEO_NOTATKA.md     |
| `critical` | Naruszenie bezpieczeństwa, nieautoryzowany dostęp, pętla agentów| Push eskalacja2 z TAK/NIE, możliwy STOP |

### Procedura zgłaszania

Każdy agent ma obowiązek zgłoszenia naruszenia przez:
```bash
.claude/hooks/watchdog_report.sh minor "opis naruszenia"
.claude/hooks/watchdog_report.sh major "opis naruszenia"
.claude/hooks/watchdog_report.sh critical "opis naruszenia"
```

### Eskalacja przy powtarzalności

- 3× `minor` w sesji → automatyczna promocja do `major`
- 1× `critical` → sesja zatrzymana do interwencji użytkownika

---

## Praca z agentami AI

### Role agentów

| Rola               | Zakres odpowiedzialności                              |
|--------------------|-------------------------------------------------------|
| `lead`             | Koordynacja, delegowanie, pilnowanie zakresu zmian    |
| `implementer`      | Realizacja kodu, testy, commit                        |
| `reviewer`         | Code review, blokowanie merge przy ryzyku             |
| `investigator`     | Eksploracja kodu, wyszukiwanie, analiza               |
| `knowledge_curator`| Walidacja i promocja obserwacji w bazie wiedzy        |

### Zasady autonomicznej pracy agentów

- Agent nie commituje bez jawnego zlecenia od użytkownika lub lead.
- Agent nie push'uje do `main` — nigdy i pod żadnym pozorem.
- Każda obserwacja wiedzy jest zgłaszana do MCP (`report_observation`).
- Agent informuje o zakończeniu pracy przez push macOS (jeśli pracował > 10 sek).
- Commit wygenerowany autonomicznie używa typu `agent:` i zawiera model AI w stopce.

### Stopka commitów agentów

```
agent: Claude Sonnet 4.6 <noreply@anthropic.com>
```
