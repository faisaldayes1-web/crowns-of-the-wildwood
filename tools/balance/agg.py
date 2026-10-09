#!/usr/bin/env python3
"""Tally a bot batch: python3 tools/balance/agg.py <tag> [<tag>...]

Reads logs/b_<tag>_*.log (RESULT, STAT and KILL lines from --demo) and
prints the win split, kills per team and class, and how in-match level
and rank points change who wins a fight."""
import collections, glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("OUT", os.path.join(HERE, "logs"))
ROLES = ["Base", "Knight", "Ranger", "Mage", "Healer", "Engineer", "Rogue"]
TEAMS = ["Elves", "Humans"]
# Class (STAT name, variants included) -> fight style, for the style table.
STYLE = {"Knight": "melee", "Vanguard": "melee", "Warden": "melee", "Rogue": "melee", "Assassin": "melee",
         "Shadow": "melee", "Base": "melee", "Engineer": "melee", "Siegewright": "melee", "Tinker": "melee",
         "Ranger": "ranged", "Sharpshooter": "ranged", "Trapper": "ranged", "Mage": "ranged",
         "Pyromancer": "ranged", "Frostweaver": "ranged",
         "Healer": "support", "Cleric": "support", "DarkPriest": "support"}


def kv(line):
    return dict(re.findall(r"(\w+)=(\S+)", line))


def main(tags):
    files = sorted(f for t in tags for f in glob.glob(os.path.join(OUT, "b_%s_*.log" % t)))
    wins = collections.Counter()
    caps = [0, 0]
    tkills = [0, 0]
    cls = collections.defaultdict(lambda: collections.Counter())
    lengths, overtime, errors = [], 0, 0
    kills = []
    down = collections.defaultdict(collections.Counter)   # event -> team -> count
    for f in files:
        text = open(f, errors="replace").read()
        errors += text.count("SCRIPT ERROR")
        res = [kv(l) for l in text.splitlines() if l.startswith("RESULT")]
        if not res:
            print("no RESULT in", os.path.basename(f))
            continue
        r = res[-1]
        wins[r["winner"]] += 1
        a, b = r["score"].split("-")
        caps[0] += int(a); caps[1] += int(b)
        lengths.append(int(r["t"]))
        overtime += r["overtime"] == "true"
        for l in text.splitlines():
            if l.startswith("STAT"):
                d = kv(l)
                t = int(d["team"])
                tkills[t] += int(d["kills"])
                c = cls[(t, d["class"])]
                c["n"] += 1
                for k in ("kills", "deaths", "assists", "dmg", "heal", "caps", "level"):
                    c[k] += int(d[k])
            elif l.startswith("KILL"):
                kills.append({k: int(v) for k, v in kv(l).items()})
            else:
                ev = l.split(" ", 1)[0]
                if ev in ("DOWN", "REVIVE", "FINISH", "BLEEDOUT", "SKIP"):
                    m = re.search(r"team(\d)", l)
                    if m:
                        down[ev][int(m.group(1))] += 1
    n = len(lengths)
    print("matches %d  wins %s  caps E%d H%d  kills E%d H%d  overtime %d  avg length %ds  script errors %d"
          % (n, dict(wins), caps[0], caps[1], tkills[0], tkills[1], overtime, sum(lengths) / max(n, 1), errors))
    print("\n%-16s %4s %6s %6s %6s %6s %6s %5s" % ("class", "n", "K/m", "D/m", "A/m", "dmg/m", "heal/m", "K/D"))
    for (t, c), v in sorted(cls.items()):
        m = max(v["n"], 1)
        print("%-16s %4d %6.1f %6.1f %6.1f %6.1f %6.1f %5.2f" % ("%s %s" % (TEAMS[t][0], c), v["n"], v["kills"] / m,
              v["deaths"] / m, v["assists"] / m, v["dmg"] / m, v["heal"] / m, v["kills"] / max(v["deaths"], 1)))
    # Fight styles: melee, ranged and support classes on each side.
    sty = collections.defaultdict(collections.Counter)
    for (t, c), v in cls.items():
        g = STYLE.get(c, "other")
        for k in ("n", "kills", "deaths", "dmg"):
            sty[(t, g)][k] += v[k]
    print("\n%-16s %4s %6s %6s %6s %5s" % ("style", "n", "K/m", "D/m", "dmg/m", "K/D"))
    for (t, g), v in sorted(sty.items()):
        m = max(v["n"], 1)
        print("%-16s %4d %6.1f %6.1f %6.1f %5.2f" % ("%s %s" % (TEAMS[t][0], g), v["n"], v["kills"] / m, v["deaths"] / m,
              v["dmg"] / m, v["kills"] / max(v["deaths"], 1)))
    if down:
        print("\ndowned per match (E/H): " + "  ".join("%s %.1f/%.1f" % (ev.lower(), down[ev][0] / max(n, 1), down[ev][1] / max(n, 1))
              for ev in ("DOWN", "REVIVE", "FINISH", "BLEEDOUT", "SKIP")))
        for t in (0, 1):
            d = max(down["DOWN"][t], 1)
            print("  %s: revived %d%%, finished %d%%, bled out %d%%, skipped %d%% of downs" % (TEAMS[t], 100 * down["REVIVE"][t] / d,
                  100 * down["FINISH"][t] / d, 100 * down["BLEEDOUT"][t] / d, 100 * down["SKIP"][t] / d))
    if not kills:
        return
    print("\nkills logged %d" % len(kills))
    vl = collections.Counter(k["vlevel"] for k in kills)
    print("victim level at death: " + "  ".join("L%d %d%%" % (l, 100 * vl[l] / len(kills)) for l in sorted(vl)))
    kl = collections.Counter(k["klevel"] for k in kills)
    print("killer level:          " + "  ".join("L%d %d%%" % (l, 100 * kl[l] / len(kills)) for l in sorted(kl)))
    # Fights between levels: of the kills where the two differ, how often the higher one won.
    diff = collections.Counter()
    for k in kills:
        d = k["klevel"] - k["vlevel"]
        diff["higher won" if d > 0 else ("lower won" if d < 0 else "same")] += 1
    print("level edge: %s" % dict(diff))
    base = [k for k in kills if k["krole"] == 0 or k["vrole"] == 0]
    b_win = sum(1 for k in base if k["krole"] == 0 and k["vrole"] != 0)
    b_lose = sum(1 for k in base if k["vrole"] == 0 and k["krole"] != 0)
    print("base soldier v classed: base killed %d, base died %d" % (b_win, b_lose))
    hi = [k for k in kills if k["vmastery"] >= 3 or k["kmastery"] >= 3]
    lo_beats_hi = sum(1 for k in kills if k["vmastery"] >= 3 and k["kmastery"] == 0)
    hi_beats_lo = sum(1 for k in kills if k["kmastery"] >= 3 and k["vmastery"] == 0)
    print("promoted (3+ points) v fresh (0 points): fresh won %d, promoted won %d" % (lo_beats_hi, hi_beats_lo))
    # Ember Pass Fire forms: kills by classes in fire form, and burn finishers.
    if any(k.get("kfire") for k in kills):
        fire = collections.Counter()
        for k in kills:
            if k.get("kfire"):
                fire[ROLES[k["krole"]]] += 1
        burns = sum(1 for k in kills if k.get("burn"))
        fk = sum(fire.values())
        print("fire form: %d kills (%d%% of all), %d finished by a burn; by class %s; fire kills on base soldiers %d"
              % (fk, 100 * fk / len(kills), burns, dict(fire), sum(1 for k in kills if k.get("kfire") and k["vrole"] == 0)))
    # When in the match people level: deaths in each third of the match by victim level.
    t3 = collections.defaultdict(collections.Counter)
    for k in kills:
        t3[min(k["t"] // 220, 3)][k["vlevel"]] += 1
    for p in sorted(t3):
        tot = sum(t3[p].values())
        avg = sum(l * c for l, c in t3[p].items()) / tot
        print("  %3d-%3ds: %3d deaths, avg victim level %.2f" % (p * 220, p * 220 + 220, tot, avg))


if __name__ == "__main__":
    main(sys.argv[1:])
