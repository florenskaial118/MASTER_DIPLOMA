#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# create_consensus_angsd — консенсус по BAM через ANGSD в Docker
# =============================================================================
# Args:
#   $1  bam_list    Файл со списком BAM, один путь на хосте в строке.
#   $2  ref         FASTA референса: имена и длины контигов.
#   $3  out_prefix  Путь без расширения. Результат: out_prefix.fa
#   $4  regions     Необязательно. Файл chr, start, end.
#                   Координаты с 1, конец включительно.
# Returns:
#   0 — успех, рядом с префиксом лежит .fa
#   1 — ошибка.
#
# -doFasta 2 — самая частая буква в позиции. Референс задаёт координаты:
# где рида нет, ANGSD пишет N, а не букву референса.
# =============================================================================
create_consensus_angsd() {
    local bam_list="$1"
    local ref="$2"
    local out_prefix="$3"
    local regions="${4:-}"

    [ -f "$bam_list" ] || { echo "ERROR: no bam list $bam_list" >&2; return 1; }
    [ -f "$ref" ] || { echo "ERROR: no ref $ref" >&2; return 1; }
    if [ -n "$regions" ] && [ ! -f "$regions" ]; then
        echo "ERROR: no regions $regions" >&2
        return 1
    fi

    local abs_list abs_ref abs_regions abs_outdir abs_out
    abs_list="$(cd "$(dirname "$bam_list")" && pwd)/$(basename "$bam_list")"
    abs_ref="$(cd "$(dirname "$ref")" && pwd)/$(basename "$ref")"
    abs_regions=""
    if [ -n "$regions" ]; then
        abs_regions="$(cd "$(dirname "$regions")" && pwd)/$(basename "$regions")"
    fi

    mkdir -p "$(dirname "$out_prefix")"
    abs_outdir="$(cd "$(dirname "$out_prefix")" && pwd)"
    abs_out="$(basename "$out_prefix")"

    samtools faidx "$abs_ref"

    local bam_dir="" bam abs_bam dir container_list
    container_list="${abs_outdir}/.${abs_out}.bamlist"
    : > "$container_list"
    while IFS= read -r bam || [ -n "$bam" ]; do
        [ -z "$bam" ] && continue
        [ -f "$bam" ] || { echo "ERROR: no bam $bam" >&2; rm -f "$container_list"; return 1; }
        abs_bam="$(cd "$(dirname "$bam")" && pwd)/$(basename "$bam")"
        dir="$(dirname "$abs_bam")"
        if [ -z "$bam_dir" ]; then
            bam_dir="$dir"
        elif [ "$dir" != "$bam_dir" ]; then
            echo "ERROR: BAMs are in different directories: $bam_dir and $dir" >&2
            rm -f "$container_list"
            return 1
        fi
        echo "/bams/$(basename "$abs_bam")" >> "$container_list"
    done < "$abs_list"

    if [ ! -s "$container_list" ]; then
        echo "ERROR: bam list is empty" >&2
        rm -f "$container_list"
        return 1
    fi

    local -a docker_args angsd_args
    docker_args=(
        --rm
        -v "$bam_dir":/bams:ro
        -v "$(dirname "$abs_ref")":/ref:ro
        -v "$abs_outdir":/out
        -w /out
    )
    angsd_args=(
        -doFasta 2
        -doCounts 1
        -minMapQ 20
        -minQ 20
        -nThreads 4
        -bam "/out/.${abs_out}.bamlist"
        -ref "/ref/$(basename "$abs_ref")"
        -out "/out/${abs_out}"
    )
    if [ -n "$abs_regions" ]; then
        if [ "$(dirname "$abs_regions")" = "$abs_outdir" ]; then
            angsd_args+=(-rf "/out/$(basename "$abs_regions")")
        else
            docker_args+=(-v "$(dirname "$abs_regions")":/regions:ro)
            angsd_args+=(-rf "/regions/$(basename "$abs_regions")")
        fi
    fi

    docker run "${docker_args[@]}" zjnolen/angsd:latest angsd "${angsd_args[@]}" \
        || { rm -f "$container_list"; return 1; }
    rm -f "$container_list"

    if [ ! -f "${abs_outdir}/${abs_out}.fa.gz" ]; then
        echo "ERROR: ANGSD did not create ${abs_out}.fa.gz" >&2
        ls -la "$abs_outdir" >&2
        return 1
    fi

    gunzip -f "${abs_outdir}/${abs_out}.fa.gz"
    echo "OK: ${abs_outdir}/${abs_out}.fa"
}
