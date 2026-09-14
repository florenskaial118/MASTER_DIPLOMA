#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# roary — строит пангеном (core alignment) по GFF-файлам в Docker
# =============================================================================
# Args:
#   $1  gff_dir   Папка с .gff-файлами (плоская, без подпапок).
#   $2  out_dir   Папка для результатов Roary.
# Returns:
#   0 — успех, в $out_dir/80_percent/ лежат core_gene_alignment.aln и др.
#   1 — ошибка.
# =============================================================================
roary() {
    local gff_dir="$1"
    local out_dir="$2"

    [ -d "$gff_dir" ] || { echo "ERROR: no dir $gff_dir" >&2; return 1; }
    mkdir -p "$out_dir"

    local abs_gff abs_out
    abs_gff="$(cd "$gff_dir" && pwd)"
    abs_out="$(cd "$out_dir" && pwd)"

    # Проверим, что .gff есть
    local n
    n=$(find "$abs_gff" -maxdepth 1 -name '*.gff' | wc -l)
    if [ "$n" -eq 0 ]; then
        echo "ERROR: no .gff files in $abs_gff" >&2
        return 1
    fi
    echo ">>> Roary: $n GFF files from $abs_gff"

    docker run --rm \
        -v "$abs_gff":/data:ro \
        -v "$abs_out":/results \
        sangerpathogens/roary \
        sh -c "roary -f /results/80_percent \
                     -e -n -v -p 8 -i 80 -cd 80 /data/*.gff"

    if [ ! -d "$abs_out/80_percent" ]; then
        echo "ERROR: Roary did not create $abs_out/80_percent" >&2
        return 1
    fi
    echo "OK: $abs_out/80_percent"
}