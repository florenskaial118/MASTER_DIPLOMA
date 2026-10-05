
import os
from Bio import SeqIO

TRANSITIONS = {
    ('A', 'G'), ('G', 'A'),
    ('C', 'T'), ('T', 'C')
}

def remove_transitions(reference_path, fasta_folder, output_folder):
    ref_record = SeqIO.read(reference_path, "fasta")
    ref_seq = str(ref_record.seq).upper()
    ref_len = len(ref_seq)

    os.makedirs(output_folder, exist_ok=True)

    print(f"Длина референса: {ref_len} п.н.\n")

    for file_name in os.listdir(fasta_folder):
        if not file_name.endswith(".fa"):
            continue

        input_path = os.path.join(fasta_folder, file_name)
        output_path = os.path.join(output_folder, f"filtered_{file_name}")

        corrected_records = []

        for record in SeqIO.parse(input_path, "fasta"):
            consensus_seq = str(record.seq).upper()

            if len(consensus_seq) != ref_len:
                print(f"⚠ {record.id}: длина {len(consensus_seq)} != {ref_len}, пропуск")
                continue

            new_seq_chars = []
            n_transitions = 0
            n_transversions = 0
            n_other_diffs = 0
            n_identical = 0
            n_removed = 0

            for ref_nuc, con_nuc in zip(ref_seq, consensus_seq):
                if ref_nuc == con_nuc:
                    n_identical += 1
                    new_seq_chars.append(con_nuc)

                elif (ref_nuc, con_nuc) in TRANSITIONS:
                    # Транзиция → удаляем позицию
                    n_transitions += 1
                    n_removed += 1
                    continue

                elif con_nuc in "ACGT":
                    # Трансверсия (или другая замена ACGT↔ACGT)
                    n_transversions += 1
                    new_seq_chars.append(con_nuc)

                else:
                    # N или другой не-ACGT символ
                    n_other_diffs += 1
                    new_seq_chars.append(con_nuc)

            record.seq = record.seq.__class__("".join(new_seq_chars))
            corrected_records.append(record)

            print(f"📄 {record.id}")
            print(f"   исходная длина:        {ref_len}")
            print(f"   удалено транзиций:     {n_removed}")
            print(f"   новая длина:           {len(new_seq_chars)}")
            print()

        if corrected_records:
            SeqIO.write(corrected_records, output_path, "fasta")
            print(f"✅ Сохранено: {output_path}\n")