create_consensus_angsd() {
    local bam_list="$1"      # абсолютный путь к файлу со списком BAM
    local ref="$2"           # абсолютный путь к референсу
    local out_prefix="$3"    # абсолютный путь без расширения, например /path/to/sample_consensus

    # Проверки
    [ -f "$bam_list" ] || { echo "ERROR: no bam list $bam_list" >&2; return 1; }
    [ -f "$ref" ]      || { echo "ERROR: no ref $ref" >&2; return 1; }

    # Абсолютные пути
    local abs_list abs_ref abs_outdir abs_out
    abs_list="$(cd "$(dirname "$bam_list")" && pwd)/$(basename "$bam_list")"
    abs_ref="$(cd "$(dirname "$ref")" && pwd)/$(basename "$ref")"

    mkdir -p "$(dirname "$out_prefix")"
    abs_outdir="$(cd "$(dirname "$out_prefix")" && pwd)"
    abs_out="$(basename "$out_prefix")"

    # Запуск: монтируем папку с BAM-листом, референс и outdir
    docker run --rm \
        -v "$(dirname "$abs_list")":/bams:ro \
        -v "$(dirname "$abs_ref")":/ref:ro \
        -v "$abs_outdir":/out \
        -w /out \
        zjnolen/angsd:latest \
        angsd -doFasta 1 \
              -doCounts 1 \
              -bam /bams/$(basename "$abs_list") \
              -ref /ref/$(basename "$abs_ref") \
              -out "/out/${abs_out}" \
              -minMapQ 20 -minQ 20

    # ANGSD создаёт ${abs_out}.fa.gz в abs_outdir
    if [ ! -f "${abs_outdir}/${abs_out}.fa.gz" ]; then
        echo "ERROR: ANGSD did not create ${abs_out}.fa.gz" >&2
        ls -la "$abs_outdir" >&2
        return 1
    fi

    # Распаковываем на хосте
    gunzip -f "${abs_outdir}/${abs_out}.fa.gz"

    echo "OK: ${abs_outdir}/${abs_out}.fasta"
}