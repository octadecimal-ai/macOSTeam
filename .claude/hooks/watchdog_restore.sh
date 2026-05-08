#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - Snapshoty inkrementalne wymagają odtworzenia w kolejności: bazowy -> przyrostowe.
# - Odtwarzanie domyślnie wykonujemy do osobnego katalogu, aby uniknąć nadpisania źródeł.

snapshot_dir=".claude/runtime/snapshots"
out_dir=""
mode="to-latest"
until_ts=""

usage() {
  echo "Użycie: $0 <katalog_docelowy> [--to-latest] [--until YYYYMMDD-HHMMSS]" >&2
  echo "Przykład (pełny do latest): $0 /tmp/experimental-lab-restore --to-latest" >&2
  echo "Przykład (do punktu czasu): $0 /tmp/experimental-lab-restore --until 20260508-143000" >&2
}

if (( $# < 1 )); then
  usage
  exit 1
fi

out_dir="${1:-}"
shift

while (( $# > 0 )); do
  case "$1" in
    --to-latest)
      mode="to-latest"
      shift
      ;;
    --until)
      if (( $# < 2 )); then
        echo "Brak wartości dla --until" >&2
        usage
        exit 1
      fi
      mode="until"
      until_ts="$2"
      if ! [[ "${until_ts}" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
        echo "Niepoprawny format --until. Oczekiwano YYYYMMDD-HHMMSS." >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Nieznany argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "${snapshot_dir}" ]]; then
  echo "Brak katalogu snapshotów: ${snapshot_dir}" >&2
  exit 1
fi

mkdir -p "${out_dir}"

# Zbierz listę archiwów snapshotów po nazwie czasowej.
mapfile -t archives < <(ls -1 "${snapshot_dir}"/*.tar.gz 2>/dev/null | sort)

if [[ "${#archives[@]}" -eq 0 ]]; then
  echo "Brak archiwów snapshotów do odtworzenia." >&2
  exit 1
fi

filtered_archives=()
if [[ "${mode}" == "until" ]]; then
  for archive in "${archives[@]}"; do
    filename="$(basename "${archive}")"
    archive_ts="${filename%%-*}"
    if [[ "${archive_ts}" < "${until_ts}" || "${archive_ts}" == "${until_ts}" ]]; then
      filtered_archives+=("${archive}")
    fi
  done
else
  filtered_archives=("${archives[@]}")
fi

if [[ "${#filtered_archives[@]}" -eq 0 ]]; then
  echo "Brak snapshotów pasujących do trybu '${mode}'." >&2
  exit 1
fi

echo "Rozpoczynam odtwarzanie do: ${out_dir}"
echo "Tryb: ${mode}"
if [[ "${mode}" == "until" ]]; then
  echo "Odtwarzanie do timestampu: ${until_ts}"
fi
echo "Liczba archiwów w łańcuchu: ${#filtered_archives[@]}"

for archive in "${filtered_archives[@]}"; do
  echo "-> Odtwarzanie: ${archive}"
  tar -xzf "${archive}" -C "${out_dir}"
done

echo "Odtwarzanie zakończone."
echo "Odtworzony katalog: ${out_dir}/experimental-lab"
