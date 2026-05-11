# Bitwarden Secrets Manager — struktura i konwencje

## Organizacja

Jedno konto BWS dla całej infrastruktury. Machine account per team z izolowanym dostępem.

## Struktura projektów

```
Organizacja BWS
├── global          — sekrety współdzielone między teamami (API keys, tokeny zewnętrzne)
└── macOSTeam       — sekrety specyficzne dla teamu macOSTeam (szablon dla fabryki)
```

Każdy nowy team tworzony przez fabrykę otrzymuje własny projekt o nazwie `{teamName}`.

## Machine accounts

| Konto         | Dostęp do projektów      |
|---------------|--------------------------|
| ma-macOSTeam  | `global` + `macOSTeam`   |
| ma-{teamName} | `global` + `{teamName}`  |

Uprawnienia: read-only do własnego projektu i `global`. Zapis przez admina lub fabrykę.

## Konwencja nazw sekretów

Nazwy kluczy uppercase z podkreślnikami, bez prefiksów środowiskowych:

```
OVH_API_KEY
OVH_API_SECRET
GITHUB_TOKEN
ANTHROPIC_API_KEY
```

## Użycie w skryptach

```bash
source /Users/experimental-lab/Lab/scripts/bws_helper.sh

export BWS_ACCESS_TOKEN="..."   # token machine account
export BWS_TEAM="macOSTeam"     # nazwa projektu teamu

# Odczyt — szuka w macOSTeam, fallback do global
api_key=$(get_secret OVH_API_KEY)

# Zapis do projektu teamu
set_secret OVH_API_KEY "nowa-wartość"

# Zapis do projektu global
set_secret GITHUB_TOKEN "nowa-wartość" global
```

## Dodawanie nowego teamu (fabryka)

1. Utwórz projekt w BWS: `bws project create {teamName}`
2. Utwórz machine account w panelu BWS: `ma-{teamName}`
3. Przypisz machine account do projektów: `global` + `{teamName}`
4. Wygeneruj access token i zapisz go bezpiecznie

## Zmienne środowiskowe

| Zmienna            | Wymagana | Opis                                      |
|--------------------|----------|-------------------------------------------|
| `BWS_ACCESS_TOKEN` | tak      | Token machine account                     |
| `BWS_TEAM`         | nie      | Nazwa projektu teamu (default: macOSTeam) |

## Rotacja tokenów

Tokeny machine account należy rotować przy podejrzeniu wycieku lub zgodnie z polityką bezpieczeństwa.

### Procedura

1. W panelu Bitwarden SM → **Machine Accounts** → `ma-{teamName}` → **Access Tokens**
2. Utwórz nowy token, skopiuj go
3. Usuń stary token z listy
4. Uruchom skrypt rotacji na maszynie admina:

```bash
bash /Users/experimental-lab/Lab/scripts/rotate_bws_token.sh
```

Skrypt wyświetli dialog z ukrytym polem tekstowym, zwaliduje nowy token wywołując BWS API, zaktualizuje Keychain i automatycznie zrestartuje watchera.

### Automatyczna detekcja

Watcher (`watch_macOSTeam.sh`) sprawdza ważność tokenu przy każdym cyklu (co 60s). Gdy token zostanie unieważniony, watcher automatycznie wywoła dialog rotacji bez potrzeby ręcznej interwencji.

> **Uwaga:** Bitwarden SM może z opóźnieniem (kilka minut) propagować unieważnienie usuniętego tokenu po stronie API. Watcher wykryje błąd przy kolejnym cyklu po unieważnieniu.

### Token w Keychain

Token przechowywany jest wyłącznie w macOS Keychain — nie pojawia się w plikach konfiguracyjnych ani repozytorium git.

| Atrybut Keychain | Wartość                                        |
|------------------|------------------------------------------------|
| Service          | `pl.octadecimal.macOSTeam.BWS_ACCESS_TOKEN`    |
| Account          | `macOSTeam-watcher`                            |

## Powiązane

- Helper: `/Users/experimental-lab/Lab/scripts/bws_helper.sh`
- Watcher: `/Users/experimental-lab/Lab/scripts/watch_macOSTeam.sh`
- Rotacja: `/Users/experimental-lab/Lab/scripts/rotate_bws_token.sh`
- LaunchAgent: `~/Library/LaunchAgents/pl.octadecimal.macOSTeam.watcher.plist`
- Issue: STORY-007 (prerekvizyt dla STORY-008 setup.sh)
- Epic: EPIC-002
