# Пример использования функции:
# download_seq "KP742478" "Mito_data/mitogenomes/test.fa"

download_assembly() {
    local code="$1"
    local output_file="$2"
    
    if [ -z "$code" ] || [ "$code" = "NA" ]; then
        touch "$output_file"
        echo "  Пустой код - создан пустой файл: $(basename $output_file)"
        return
    fi
    
    echo "  Скачиваю: $code"
    
    # Скачиваем сборку целиком в временную директорию
    local temp_dir=$(mktemp -d)
    
    if datasets download genome accession "$code" --filename "$temp_dir/$code.zip" 2>/dev/null; then
        # Распаковываем и извлекаем fasta
        unzip -q "$temp_dir/$code.zip" -d "$temp_dir"
        
        # Находим файл с последовательностью (обычно *.fna)
        local fasta_file=$(find "$temp_dir/ncbi_dataset/data/$code" -name "*.fna" 2>/dev/null | head -1)
        
        if [ -f "$fasta_file" ] && [ -s "$fasta_file" ]; then
            cp "$fasta_file" "$output_file"
            echo "  Успешно: $(basename $output_file)"
        else
            echo "  Ошибка: не найден fasta файл"
            touch "$output_file"
        fi
        
        # Очищаем
        rm -rf "$temp_dir"
    else
        echo "  Ошибка скачивания - создаю пустой файл"
        touch "$output_file"
    fi
}
