#!/bin/bash

# Поиск и формирование таблицы со сборками генома для заданного организма
# Аргументы:
#   $1 - название организма (таксон)
# Возвращает:
#   TSV-таблицу с колонками: AssemblyAccession, Assembly_name, Assembly_status, 
#   SpeciesName, Strain, BioSampleAccn, BioProject, Total_length, Contig_count,
#   Completeness, Contamination, ScaffoldN50, Isolation_source
# Особенности:
#   - Работает с помощью пакета datasets (conda install -c conda-forge ncbi-datasets-cli)
#   - Удаляет дубликаты по Assembly_name (сохраняет первую запись)
#   - Сортирует по Assembly_status
#   - Нет важных данных об образце - дата и место сбора
get_assembly_summary() {
    local organism="$1"
    
    local header="AssemblyAccession\tAssembly_name\tAssembly_status\tSpeciesName\tStrain\tBioSampleAccn\tBioProject\tTotal_length\tContig_count\tCompleteness\tContamination\tScaffoldN50\tIsolation_source"
    
    (echo -e "$header"; datasets summary genome taxon "$organism" --as-json-lines 2>/dev/null  | \
    jq -r '
        [.accession, 
         .assembly_info.assembly_name,
         .assembly_info.assembly_level,
         .organism.organism_name,
         (.assembly_info.biosample.strain // "-"),
         (.assembly_info.biosample.accession // "-"),
         (.assembly_info.bioproject_accession // "-"),
         (.assembly_stats.total_sequence_length // "-"),
         (.assembly_stats.number_of_contigs // "-"),
         (.checkm_info.completeness // "-"),
         (.checkm_info.contamination // "-"),
         (.assembly_stats.scaffold_n50 // "-"),
         (.assembly_info.biosample.isolation_source // "-")] | @tsv') | \
    awk 'NR==1 {print; next} !seen[$2]++' | \
    sort -k3
}

# Поиск данных о времени и месте сбора образца
# Аргументы:
#   $1 - код образца (biosample)
# Возвращает:
#   TSV-таблицу с колонками: BioSampleAccn, Country, Collection_date
# Особенности:
#   - Работает с помощью пакета etools (из ncbi-EntrezDirect)
#   - Дополняет работу предыдущей функции
search_biosample_data() {
    local biosample="$1"
    local header="BioSampleAccn\tCollection_date\tCountry\tHost"
    
    # Проверяем, что biosample не пустой
    if [ -z "$biosample" ] || [ "$biosample" = "-" ]; then
        echo -e "$biosample\t-\t-"
        return
    fi
    
    (echo -e "$header"; \
     esearch -db biosample -query "$biosample" 2>/dev/null | \
     efetch -format docsum 2>/dev/null | \
     xtract -pattern DocumentSummary \
         -element Accession \
         -block "SampleData/BioSample/Attributes/Attribute" \
         -if Attribute@attribute_name -equals "collection_date" -or \
         Attribute@attribute_name -equals "collection date"  \
         -def "-" -first -element Attribute \
         -block "SampleData/BioSample/Attributes/Attribute" \
         -if Attribute@attribute_name -equals "geo_loc_name" -or \
         Attribute@attribute_name -equals "geographic location (country and/or sea)" -or \
         Attribute@attribute_name -equals "country"  \
         -def "-" -first -element Attribute \
         -block "SampleData/BioSample/Attributes/Attribute" \
         -if  Attribute@attribute_name -equals "host scientific name" -or \
         Attribute@attribute_name -equals "host" -or \
         Attribute@attribute_name -equals "metagenome source" -or \
         Attribute@attribute_name -equals "broad-scale environmental context" -or \
          Attribute@attribute_name -equals "environment (feature)" \
         -def "-" -first -element Attribute  2>/dev/null )
}

# Основная функция, объединяющая получение сборок и данных о biosample
# Аргументы:
#   $1 - название организма (таксон)
#   $2 - выходной файл (опционально)
get_complete_assembly_summary() {
    local organism="$1"
    local output_file="${2:-assembly_summary_complete.tsv}"
    
    # Получаем базовую таблицу сборок
    echo "Получение данных о сборках для $organism..." >&2
    local temp_file=$(mktemp)
    get_assembly_summary "$organism" > "$temp_file"
    
    # Создаем заголовок для выходного файла с дополнительными колонками
    local header="AssemblyAccession\tAssembly_name\tBioProject\tAssembly_status\tSpeciesName\tTotal_length\tContig_count\tCompleteness\tContamination\tScaffoldN50\tBioSampleAccn\tCollection_date\tCountry\tHost"
    echo -e "$header" > "$output_file"
    
    # Обрабатываем каждую строку (пропускаем заголовок)
    tail -n +2 "$temp_file" | while IFS=$'\t' read -r AssemblyAccession Assembly_name Assembly_status SpeciesName Strain BioSampleAccn BioProject Total_length Contig_count Completeness Contamination ScaffoldN50 Isolation_source; do
        echo "Обработка: $AssemblyAccession - $BioSampleAccn" >&2
        
        # Получаем данные о biosample
        local geo_data=$(search_biosample_data "$BioSampleAccn" < /dev/null  | tail -n +2)
        
        # Записываем результат
        if [ -n "$geo_data" ]; then
            # geo_data содержит BioSampleAccn, Country, Collection_date
            echo -e "$AssemblyAccession\t$Assembly_name\t$BioProject\t$Assembly_status\t$SpeciesName\t$Total_length\t$Contig_count\t$Completeness\t$Contamination\t$ScaffoldN50\t$geo_data" >> "$output_file"
        else
            # Если данных нет, записываем с прочерками
            echo -e "$AssemblyAccession\t$Assembly_name\t$BioProject\t$Assembly_status\t$SpeciesName\t$Total_length\t$Contig_count\t$Completeness\t$Contamination\t$ScaffoldN50\t$BioSampleAccn\t-\t-\t-" >> "$output_file"
        fi
    done
    
    # Удаляем временный файл
    rm -f "$temp_file"
    
    echo "Готово! Результат сохранен в $output_file" >&2
}


# Основной блок выполнения
main() {
    if [ $# -ge 2 ]; then
        get_complete_assembly_summary "$1" "$2"
    else
        get_complete_assembly_summary "$1"
    fi
}

# Запускаем main, если скрипт выполняется напрямую
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi