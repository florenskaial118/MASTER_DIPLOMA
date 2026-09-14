# Выводит данные о сборке по ее номеру
get_assembly_metadata() {
    local organism="$1"
    header="AssemblyAccession\tAssembly_name\tAssembly_status\tSpeciesName\tBioSampleAccn\tScaffoldN50\tLastUpdateDate"
    
    (echo -e "$header"; esearch -db assembly -query "${organism}" | \
    efetch -format docsum | \
    xtract -pattern DocumentSummary \
      -tab "\t" -sep "," \
      -element AssemblyAccession AssemblyName Meta/assembly-status SpeciesName BioSampleAccn \
     ScaffoldN50 LastUpdateDate | sort -k2) | column -t -s $'\t' 
}