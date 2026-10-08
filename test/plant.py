# SPDX-License-Identifier: Apache-2.0
# Known bugs planted one at a time, to score a reviewer: a finding counts only if its
# reproducer fails on the planted copy and passes on a clean one. Copies go under _plant/.
# Usage: python3 test/plant.py screen [--plant NAME ...] [--jobs N]  which bugs runtest misses
#        python3 test/plant.py export NAME DIR  a planted copy, without this file
#        python3 test/plant.py grade NAME DIR   DIR/repro.sh on clean and planted
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COPIED = ["src", "test", "bin", "python", "pio", "formal", "ppx", "demo", "pages", "dune-project",
          ".ocamlformat", "protocol_emulator.opam"]
SKIPPED = shutil.ignore_patterns("sim_build", "__pycache__", "*.fst", "*.vcd", "results.xml",
                                 "_build", "plant.py")

# name, area, file, text, planted text
PLANTS = [
    ("sent_short_pause", "firmware", "test/sent.ml",
     "    set pins, 1\n" + "    add t, p\n" * 6 + "    add t, p                 ; 12 ticks",
     "    set pins, 1\n" + "    add t, p\n" * 5 + "    add t, p                 ; 12 ticks"),
    ("cec_free_six", "firmware", "test/cec.ml",
     "    set y, 6                 ; signal free time, seven bit periods\n",
     "    set y, 5                 ; signal free time, seven bit periods\n"),
    ("dshot_gap", "firmware", "test/dshot.ml",
     "    set y, 7\ngap:\n", "    set y, 4\ngap:\n"),
    ("self_check_lead", "firmware", "src/self_check.ml",
     "let lead = 2\n", "let lead = 3\n"),
    ("self_check_span", "firmware", "src/self_check.ml",
     "let capture_span = 1 lsl 14\n", "let capture_span = 1 lsl 15\n"),
    ("cec_new_frame_five", "oracle", "test/cec.ml",
     "if retry then 3 else 7", "if retry then 3 else 5"),
    ("cec_start_long", "oracle", "test/cec.ml",
     "~hi:(47 * ms / 10)", "~hi:(49 * ms / 10)"),
    ("sent_sync_drift", "oracle", "test/sent.ml",
     "abs (sync - previous) * 64 > previous", "abs (sync - previous) * 32 > previous"),
    ("sent_pause_long", "oracle", "test/sent.ml",
     "56 * pause <= 768 * sync", "56 * pause <= 1024 * sync"),
    ("sent_low_four", "oracle", "test/sent.ml",
     "if 56 * low > 4 * sync", "if 56 * low >= 4 * sync"),
    ("pio_side_set", "pio checker", "pio/src/timing.ml",
     "    && List.exists side ~f:(fun side -> Option.is_some (level_of_write pin side)))",
     "    && List.for_all side ~f:(fun side -> Option.is_some (level_of_write pin side)))"),
    ("pio_clkdiv_truncate", "pio checker", "pio/src/timing.ml",
     "single (single clkdiv +. (0.5 /. 256.))", "single (single clkdiv +. 0.)"),
    ("pio_margin_abs", "pio checker", "pio/src/timing.ml",
     'sprintf "%.2f%%" (ratio *. 100.)', 'sprintf "%.2f%%" (Float.abs ratio *. 100.)'),
    ("kernel_space", "kernel", "src/kernel.ml",
     "mux2 (base >=:. space) (base -:. space) base", "mux2 (base >:. space) (base -:. space) base"),
    ("kernel_ne_overlap", "kernel", "src/kernel.ml",
     "(row.x_lo <=: row.y_hi &: (row.y_lo <=: row.x_hi))",
     "(row.x_lo <: row.y_hi &: (row.y_lo <=: row.x_hi))"),
    ("kernel_taken_lo", "kernel", "src/kernel.ml",
     "(zero Isa.data_bits) (lo -:. 1)", "(zero Isa.data_bits) lo"),
    ("kernel_arm_limit", "kernel", "src/kernel.ml",
     "(wide_arm <:. arm_limit)", "(wide_arm <=:. arm_limit)"),
    ("analyser_capture_age", "analyser", "src/analyser.ml",
     "Option.map since.hi ~f:(fun hi -> hi - 1)", "Option.map since.lo ~f:(fun hi -> hi - 1)"),
    ("analyser_fraction", "analyser", "src/analyser.ml",
     "Interval.plus s.period { lo = Some 0; hi = Some 1 }",
     "Interval.plus s.period { lo = Some 1; hi = Some 1 }"),
    ("rtl_late", "rtl", "src/deadline.ml",
     "release ~now ~t &: (phase ~now ~t <>:. 0)", "release ~now ~t"),
    ("rtl_crc_mask", "rtl", "src/crc.ml",
     "mux2 reflect reflected forward &: mask", "mux2 reflect (reflected &: mask) forward"),
    ("rtl_spi_last_bit", "rtl", "src/host_spi.ml",
     "sck_rise &: (count ==:. 7)", "sck_rise &: (count ==:. 6)"),
    ("rtl_memory_turn", "rtl", "src/data_memory.ml",
     "reg spec (turn ==:. n &: ~:write)", "reg spec (turn ==:. n)"),
    ("i2c_fmp_su_sto", "oracle", "test/i2c_timing.ml",
     "    ~su_dat:50\n    ~su_sto:260\n", "    ~su_dat:50\n    ~su_sto:250\n"),
    ("host_load_fill", "host", "python/protocol_emulator.py",
     "[0] * (PROGRAM_WORDS - address - len(words))", "[0] * (PROGRAM_WORDS - len(words))"),
    ("host_config_reserved", "host", "python/protocol_emulator.py",
     '    None, None, "autopull_data", "manchester",', '    None, "autopull_data", "manchester",'),
    ("host_rx_level", "host", "python/protocol_emulator.py",
     '"rx_level": (s >> 10) & 15', '"rx_level": (s >> 10) & 7'),
]


def find(name):
    for plant in PLANTS:
        if plant[0] == name:
            return plant
    sys.exit(f"no plant {name}")


def copy(dest, plant=None):
    # dune's _build stays, so the next copy, and the next screen, rebuilds only what changed
    dest.mkdir(parents=True, exist_ok=True)
    for item in dest.iterdir():
        if item.name != "_build":
            shutil.rmtree(item) if item.is_dir() else item.unlink()
    for item in COPIED:
        if (ROOT / item).is_dir():
            shutil.copytree(ROOT / item, dest / item, ignore=SKIPPED)
        else:
            shutil.copy(ROOT / item, dest / item)
    if plant:
        _, _, file, text, planted = plant
        source = (dest / file).read_text()
        if source.count(text) != 1:
            sys.exit(f"{plant[0]}: the text is not in {file} exactly once")
        (dest / file).write_text(source.replace(text, planted))


def dune(cwd, jobs, *args):
    return subprocess.run(["dune", *args, "--root", ".", "-j", str(jobs)], cwd=cwd,
                          capture_output=True, text=True)


# A build that fails past type checking (a [%firmware] refusal, or a rule that runs the
# kernel on firmware) has caught the plant. One that fails to type check is no plant.
def verdict(work, jobs):
    if dune(work, jobs, "build").returncode != 0:
        check = dune(work, jobs, "build", "@check")
        if check.returncode != 0 and "[%firmware]" not in check.stderr:
            return "invalid"
        return "killed"
    return "survived" if dune(work, jobs, "build", "@runtest").returncode == 0 else "killed"


def screen(names, jobs):
    work = ROOT / "_plant" / "screen"
    copy(work)
    clean = dune(work, jobs, "build", "@default", "@runtest")
    if clean.returncode != 0:
        sys.exit(f"the clean copy fails:\n{clean.stderr[-2000:]}")
    plants = [find(n) for n in names] if names else PLANTS
    killed = 0
    for plant in plants:
        copy(work, plant)
        result = verdict(work, jobs)
        killed += result == "killed"
        print(f"{result:9} {plant[0]} ({plant[1]}, {plant[2]})", flush=True)
    print(f"{killed} of {len(plants)} killed")


# A reproducer is DIR/repro.sh, run from the copy's root: it must pass on the clean copy
# and fail on the planted one.
def grade(name, finding):
    repro = (Path(finding) / "repro.sh").resolve()
    verdicts = {}
    for label, plant in [("clean", None), ("planted", find(name))]:
        work = ROOT / "_plant" / label
        copy(work, plant)
        verdicts[label] = subprocess.run(["bash", str(repro)], cwd=work).returncode
        shutil.rmtree(work, ignore_errors=True)
    found = verdicts["clean"] == 0 and verdicts["planted"] != 0
    print(f"{name}: clean exits {verdicts['clean']}, planted {verdicts['planted']}: "
          + ("found" if found else "not found"))
    sys.exit(0 if found else 1)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("screen")
    s.add_argument("--plant", action="append")
    s.add_argument("--jobs", type=int, default=4)
    e = sub.add_parser("export")
    e.add_argument("name")
    e.add_argument("dir")
    g = sub.add_parser("grade")
    g.add_argument("name")
    g.add_argument("dir")
    args = p.parse_args()
    if args.command == "screen":
        screen(args.plant, args.jobs)
    elif args.command == "export":
        if Path(args.dir).exists():
            sys.exit(f"{args.dir} exists")
        copy(Path(args.dir).resolve(), find(args.name))
    else:
        grade(args.name, args.dir)


if __name__ == "__main__":
    main()
