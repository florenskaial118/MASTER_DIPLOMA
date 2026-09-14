#!/bin/bash
# Шаблоны поиска в NCBI через E-Utilities и datasets

# Функция для поиска таксономии
#conda install -c conda-forge ncbi-datasets-cli
get_taxonomy() {
    local species_name="$1"
    
    (datasets summary taxonomy taxon "$species_name" --as-json-lines | \
dataformat tsv taxonomy --template tax-summary | \
awk -F'\t' 'NR==1{split($0,h)} NR==2{for(i=1;i<=NF;i++) print h[i] "\t" $i}'; echo '---') | column -t -s $'\t' 
}

get_names_of_relatives() {
    local species_name="$1"

    header="Id\tDivision\tScientificName\tRank\tCommonName"

    (echo -e "$header"; esearch -db taxonomy -query "$species_name[orgn]" |\
    efetch  -format docsum |\
    xtract -pattern DocumentSummary \
    -element Id,Division,ScientificName,Rank,CommonName | sort -k3; echo '---' ) | column -t -s $'\t'
}

# Функция для поиска в биопроектах
search_bioproject() {
    local organism="$1"
    header="Project_Acc\tProject_Title\tProject_Data_Type\tProject_Target_Scope\tProject_Target_Material\tRegistration_Date"
    
    (echo -e "$header"; esearch -db bioproject -query "${organism}" | \
    efetch -format docsum | \
    xtract -pattern DocumentSummary \
      -tab "\t" -sep "," \
      -element Project_Acc Project_Title Project_Data_Type \
      Project_Target_Scope Project_Target_Material Registration_Date) | column -t -s $'\t'
}

# Функция для поиска в сборках
search_assembly() {
    local organism="$1"
    header="AssemblyAccession\tAssembly_name\tAssembly_status\tSpeciesName\tBioSampleAccn\tScaffoldN50\tLastUpdateDate"
    
    (echo -e "$header"; esearch -db assembly -query "${organism}" | \
    efetch -format docsum | \
    xtract -pattern DocumentSummary \
      -tab "\t" -sep "," \
      -element AssemblyAccession AssemblyName Meta/assembly-status SpeciesName BioSampleAccn \
     ScaffoldN50 LastUpdateDate | sort -k2) | column -t -s $'\t' 
}

tab_search_assembly_datasets() {
    local organism="$1"
    
    header="AssemblyAccession\tAssembly_name\tAssembly_status\tSpeciesName\tStrain\tBioSampleAccn\tBioProject\tTotal_length\tContig_count\tCompleteness\tContamination\tScaffoldN50\tIsolation_source"
    
    (echo -e "$header"; datasets summary genome taxon "$organism" --as-json-lines 2>/dev/null | \
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
         (.assembly_info.biosample.isolation_source // "-")] | 
        map(if . == null then "-" elif . == 0 then "0" else tostring end) | @tsv') | \
    awk 'NR==1 {print; next} !seen[$2]++' | \
    sort -k3
}

search_biosample_data() {
    local biosample="$1"
    local header="\tBioSampleAccn\tCountry\tCollection_date\tIsolation_source\tStrain\tLatitude\tLongitude\tAbstract"
    
    (echo -e "$header"; esearch -db biosample -query "$biosample" | efetch -format docsum | \
    xtract -pattern DocumentSummary \
      -element Accession \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "geo_loc_name" -or \
         Attribute@attribute_name -equals "geographic location (country and/or sea)" -or \
         Attribute@attribute_name -equals "country" \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "collection_date" -or \
         Attribute@attribute_name -equals "collection date" \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "host_tissue_sampled" -or \
         Attribute@attribute_name -equals "isolation_source" -or \
         Attribute@attribute_name -equals "isolation source" \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "strain" \
      -def "-" -element Attribute \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "geographic location (latitude)" -or \
         Attribute@attribute_name -equals "latitude" \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "geographic location (longitude)" -or \
         Attribute@attribute_name -equals "longitude" \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "lat_lon" \
      -def "-" -element Attribute \
      -block "SampleData/BioSample/Attributes/Attribute" \
      -if Attribute@attribute_name -equals "project name" -or \
         Attribute@attribute_name -equals "project_name" )
}

# Функция для поиска в SRA
search_sra() {
    local organism="$1"
    header="Run\tBioProject\tScientificName\tLibraryStrategy\tPlatform\tCenterName"
    
    echo -e "$header"
    esearch -db sra -query "${organism}[orgn]" | \
    efetch -format runinfo | \
    cut -d',' -f1,2,8,11,21,28
}

#Функция для поиска в Nucleotide
search_Nucleotide() {
    local text="$1"
    header="AccessionVersion\tTitle\tOrganism\tTaxId\tSlen\tMolType\tTopology\tBiomol\tCreateDate"

    (echo -e "$header"; esearch -db nucleotide -query "${text}" | \
    efetch -format docsum | \
    xtract -pattern DocumentSummary  \
    -element AccessionVersion \
    -element Title \
    -element Organism TaxId \
    -element Slen MolType Topology Biomol \
    -element CreateDate; echo '---') | column -t -s $'\t'
}

# Функция для поиска в Pubmed
search_PubMed() {
    local organism="$1"
    header="PMID\tArticleTitle\tPubDate\tAuthors"

    (echo -e "$header"; esearch -db pubmed -query "${organism}" | \
    efetch -format xml | \
    xtract -pattern PubmedArticle -element MedlineCitation/PMID \
        ArticleTitle \
        -block PubDate -sep " " -element Year,Month \
        -block AuthorList -num Author -sep "/" -element LastName; echo '---' ) | column -t -s $'\t'
}

# Фунция для скачивания данных по коду доступа

download_seq() {
    local code="$1"        # Код доступа (например, KP742478)
    local output_file="$2" # Куда сохранить
    
    # Если код пустой или NA - создаём пустой файл
    if [ -z "$code" ] || [ "$code" = "NA" ]; then
        touch "$output_file"
        echo "  Пустой код - создан пустой файл: $(basename $output_file)"
        return
    fi
    
    # Пробуем скачать
    echo "  Скачиваю: $code"
    
    # Простая попытка скачивания
    if efetch -db nucleotide -id "$code" -format fasta > "$output_file" 2>/dev/null; then
        # Проверяем, что файл не пустой и содержит последовательность
        if [ -s "$output_file" ] && grep -q ">" "$output_file"; then
            echo "  Успешно: $(basename $output_file)"
        else
            echo "  Ошибка: файл пустой - создаю пустой"
            touch "$output_file"
        fi
    else
        echo "  Ошибка скачивания - создаю пустой файл"
        touch "$output_file"
    fi
}

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

# Пример использования функции:
# download_seq "KP742478" "Mito_data/mitogenomes/test.fa"

download_gff() {
    local accession="$1"
    local output_dir="$2"
    
    # Создаём папку, если её нет
    mkdir -p "$output_dir"
    
    echo "  Скачиваю GFF для $accession"
    
    # Пробуем скачать через datasets
    datasets download genome accession "$accession" --include gff3 --filename "${accession}.zip" 2>/dev/null
    
    if [ -f "${accession}.zip" ]; then
        unzip -q "${accession}.zip" -d "${accession}_temp"
        
        # Ищем gff файл
        gff_file=$(find "${accession}_temp" -name "*.gff" | head -1)
        
        if [ -n "$gff_file" ] && [ -f "$gff_file" ]; then
            cp "$gff_file" "${output_dir}/${accession}.gff"
            rm -rf "${accession}_temp" "${accession}.zip"
            echo "    ✓ GFF сохранён: ${output_dir}/${accession}.gff"
            return 0
        else
            rm -rf "${accession}_temp" "${accession}.zip"
            echo "    ✗ GFF не найден в скачанном архиве для $accession"
            return 1
        fi
    else
        echo "    ✗ Не удалось скачать архив GFF для $accession"
        return 1
    fi
}