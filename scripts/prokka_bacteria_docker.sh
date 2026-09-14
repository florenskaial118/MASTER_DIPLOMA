# Аргументы:
#   $1  prefix   (string)  Префикс для выходных файлов Prokka. Обычно
#                          совпадает с именем сборки (например, GCA_963526385.1).
#                          Все файлы Prokka будут названы <prefix>.*
#                          (prefix.gff, prefix.faa, prefix.gbk, ...).
#
#   $2  outdir   (path)    Папка на хосте, куда Prokka сложит результаты.
#                          Создаётся, если не существует. Внутри контейнера
#                          монтируется как /outdir.
#
#   $3  input    (path)    Путь к входному файлу сборки в формате FASTA
#                          (.fa/.fasta/.fna). Должен существовать.
#                          Монтируется в контейнер как /input.fa (ro).
#
prokka() {
    local prefix="$1"
    local outdir="$2"
    local input="$3"

    echo "=== prokka_old debug ==="
    echo "prefix: $prefix"
    echo "outdir: $outdir"
    echo "input:  $input"

    local abs_input abs_outdir
    abs_input="$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"

    mkdir -p "$outdir" || { echo "ERROR: mkdir $outdir" >&2; return 1; }
    abs_outdir="$(cd "$outdir" && pwd)"

    echo "abs_input:  $abs_input"
    echo "abs_outdir: $abs_outdir"

    docker run --rm \
        --platform linux/amd64 \
        -v "$abs_input":/input.fa:ro \
        -v "$abs_outdir":/outdir \
        staphb/prokka:latest \
        prokka --outdir /outdir \
               --prefix "$prefix" \
               --kingdom Bacteria \
               --cpus 10 \
               --force \
               /input.fa


    if [ ! -f "$abs_outdir/${prefix}.gff" ]; then
        echo "ERROR: no ${prefix}.gff in $abs_outdir" >&2
        ls -la "$abs_outdir" >&2
        return 1
    fi

    echo "OK: $abs_outdir/${prefix}.gff"
}               

# Аргументы:
#   $1  path    (dir)  Папка с входными сборками (*.fa).
#   $2  outdir  (dir)  Базовая папка для результатов Prokka.
#                      Для каждой сборки создаётся подпапка:
#                      <outdir>/<assembly_name>/
#   $3  gff     (dir)  Папка, куда копируются только .gff-файлы
#                      (удобно для Roary/Panaroo).
#
# Логика:
#   - Пропускает сборки, для которых <gff>/<assembly_name>.gff уже есть.
#   - Для каждой новой сборки вызывает prokka().
#   - Копирует <outdir>/<name>/<name>.gff в <gff>/<name>.gff.
main() {
    local path="$1"
    local outdir="$2"
    local gff="$3"

    for assembly_file in $path/*.fa; do
        local assembly_name
        assembly_name=$(basename "$assembly_file" .fa)

        [ -e "$assembly_file" ] || continue
        

        if [ -f "$gff/${assembly_name}.gff" ]; then
            echo "Skip $assembly_name (already done)"
            continue
        fi

        if [ -f "$outdir/$assembly_name/${assembly_name}.gff" ]; then
            cp "$outdir/$assembly_name/${assembly_name}.gff" "$gff/${assembly_name}.gff"
            echo "Skip $assembly_name (already done)"
            continue
        fi

        echo ">>> Prokka for $assembly_name"
        prokka "$assembly_name" "$outdir/$assembly_name" "$assembly_file" 

        cp "$outdir/$assembly_name/${assembly_name}.gff" "$gff/${assembly_name}.gff"    
    done
}

main "$@"