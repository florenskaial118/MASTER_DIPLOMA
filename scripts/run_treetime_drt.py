import argparse
import os
import re
import subprocess
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description="Run a Date Randomization Test (DRT) with TreeTime.")
parser.add_argument("-t", "--tree", required=True, help="Path to input Newick tree file")
parser.add_argument("-a", "--aln", required=True, help="Path to input FASTA alignment")
parser.add_argument("-d", "--dates", required=True, help="Path to CSV file with 'name,date' columns")
parser.add_argument("-o", "--outdir", required=True, help="Output directory")
parser.add_argument("-n", "--reps", type=int, default=20, help="Number of random replicates (default: 20)")
parser.add_argument("--reroot", default="least-squares", help="TreeTime reroot method (default: least-squares)")
parser.add_argument("--seed", type=int, default=42, help="Random seed (default: 42)")
args = parser.parse_args()

os.makedirs(args.outdir, exist_ok=True)
rng = np.random.default_rng(args.seed)

def get_clock_stats(dates_path, run_outdir):
    cmd = [
        "treetime", "clock",
        "--tree", args.tree,
        "--aln", args.aln,
        "--dates", dates_path,
        "--reroot", args.reroot,
        "--outdir", run_outdir
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    output = res.stdout + "\n" + res.stderr

    rate_match = re.search(r"--rate:\s+([0-9.eE+-]+)", output)
    r2_match = re.search(r"--r\^2:\s+([0-9.eE+-]+)", output)

    if not rate_match:
        raise RuntimeError(f"TreeTime failed on {dates_path}:\n{output}")

    rate = float(rate_match.group(1))
    r2 = float(r2_match.group(1)) if r2_match else np.nan
    return rate, r2

# 1. Run on real dates
print("Running TreeTime on REAL dates...")
real_rate, real_r2 = get_clock_stats(args.dates, os.path.join(args.outdir, "real"))
print(f"Real rate: {real_rate:.3e} | R^2: {real_r2:.3f}\n")

# 2. Run on shuffled replicates
df = pd.read_csv(args.dates)
random_rates = []
random_r2s = []

for i in range(1, args.reps + 1):
    df_shuf = df.copy()
    df_shuf["date"] = rng.permutation(df["date"].values)
    
    shuf_csv = os.path.join(args.outdir, f"shuf_{i}.csv")
    shuf_out = os.path.join(args.outdir, f"rep_{i}")
    df_shuf.to_csv(shuf_csv, index=False)
    
    rate, r2 = get_clock_stats(shuf_csv, shuf_out)
    random_rates.append(rate)
    random_r2s.append(r2)
    print(f"Rep {i}/{args.reps}: rate = {rate:.3e} | R^2 = {r2:.3f}")

# 3. Save table & plot
results = pd.DataFrame({
    "run": ["real"] + [f"rep_{i}" for i in range(1, args.reps + 1)],
    "rate": [real_rate] + random_rates,
    "r2": [real_r2] + random_r2s
})
results.to_csv(os.path.join(args.outdir, "drt_results.csv"), index=False)

plt.figure(figsize=(8, 7))
plt.scatter(range(1, args.reps + 1), random_rates, color="steelblue", label="Shuffled dates")
plt.axhline(real_rate, color="crimson", linestyle="--", linewidth=2, label=f"Real rate ({real_rate:.2e})")
plt.ylabel('Скорость замен (замен / сайт / год)', fontsize=16)
plt.xlabel('Номер повтора (реплики)', fontsize=16)
plt.xticks(range(0, args.reps + 1, 2), fontsize=13)
plt.yticks(fontsize=13)
plt.legend()
#plt.grid(alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(args.outdir, "drt_plot.png"), dpi=300)
plt.savefig("../results/figures/drt_plot.png", dpi=300)

# 4. Summary
print("\n--- SUMMARY ---")
print(f"Real rate        : {real_rate:.3e} (R^2 = {real_r2:.3f})")
print(f"Max shuffled rate: {max(random_rates):.3e} (Max R^2 = {max(random_r2s):.3f})")
print("Result           :", "PASSED" if real_rate > max(random_rates) else "FAILED / OVERLAP")
