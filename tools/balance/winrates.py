#!/usr/bin/env python3
"""Win rates from a bot batch: python3 tools/balance/winrates.py <tag> [<tag>...]

Reads logs/b_<tag>_*.log (RESULT and STAT lines from --demo, see runbatch.sh)
and prints, per map and per class (the class each bot ended the match as,
so promotions show as their variant), how often the side fielding it won.
A draw counts as half a win. The map comes from the tag when it ends in
_m<index> (runbatch.sh MAP=<index> with a tag like base_m2), else "?".

In a 4v4 bot match both sides field one of each LINEUP class, so a class
line (Knight, Ranger, Mage, Healer) is 50% by construction; the numbers that
mean something are the variants (Warden v Vanguard, ...) and the faction
splits. Also prints match length so the 12-15 minute target can be checked.
Agent: claude-faisallaptop/crowns-balance."""
import collections, glob, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("OUT", os.path.join(HERE, "logs"))
TEAMS = ["Elves", "Humans"]
MAPS = ["Wildwood", "Moonlit", "Ember Pass", "Stonekeep", "Twilight"]
LINE = {"Knight": "Knight", "Vanguard": "Knight", "Warden": "Knight",
        "Ranger": "Ranger", "Sharpshooter": "Ranger", "Trapper": "Ranger",
        "Mage": "Mage", "Pyromancer": "Mage", "Frostweaver": "Mage",
        "Healer": "Healer", "Cleric": "Healer", "DarkPriest": "Healer",
        "Engineer": "Engineer", "Artificer": "Engineer", "Siegewright": "Engineer",
        "Rogue": "Rogue", "Assassin": "Rogue", "Nightrunner": "Rogue"}


def kv(line):
    return dict(re.findall(r"(\w+)=(\S+)", line))


def ci(w, n):
    """Half-width of a 95% normal interval on a win rate, in points."""
    if n == 0:
        return 0.0
    p = w / n
    return 196 * math.sqrt(max(p * (1 - p), 0.0625) / n)   # floor at p=0.25 so tiny samples never look tight


def main(tags):
    files = sorted(f for t in tags for f in glob.glob(os.path.join(OUT, "b_%s_*.log" % t)))
    maps = collections.defaultdict(lambda: collections.Counter())
    cls = collections.defaultdict(lambda: collections.Counter())
    lengths = []
    errors = 0
    for f in files:
        text = open(f, errors="replace").read()
        errors += text.count("SCRIPT ERROR")
        res = [kv(l) for l in text.splitlines() if l.startswith("RESULT")]
        if not res:
            print("no RESULT in", os.path.basename(f))
            continue
        r = res[-1]
        m = re.search(r"_m(\d)_\d+\.log$", f)
        mp = MAPS[int(m.group(1))] if m else "?"
        win = [0.5, 0.5] if r["winner"] not in TEAMS else [1.0 * (r["winner"] == TEAMS[0]), 1.0 * (r["winner"] == TEAMS[1])]
        t = int(r["t"])
        lengths.append(t)
        mc = maps[mp]
        mc["n"] += 1; mc["E"] += win[0]; mc["t"] += t
        mc["ot"] += r.get("overtime") == "true"
        mc["in"] += 720 <= t <= 1020   # 12-15 min plus the 120 s overtime
        mc["short"] += t < 720
        a, b = r["score"].split("-")
        mc["capsE"] += int(a); mc["capsH"] += int(b)
        for l in text.splitlines():
            if not l.startswith("STAT"):
                continue
            d = kv(l)
            team = int(d["team"])
            for key in ((d["class"], None), (d["class"], team)):
                c = cls[key]
                c["n"] += 1; c["w"] += win[team]
                c["k"] += int(d["kills"]); c["d"] += int(d["deaths"]); c["dmg"] += int(d["dmg"])
    n = len(lengths)
    print("matches %d  script errors %d  avg length %.0f s  median %d s  shortest %d s  longest %d s"
          % (n, errors, sum(lengths) / max(n, 1), sorted(lengths)[n // 2] if n else 0, min(lengths or [0]), max(lengths or [0])))
    print("\n| Map | Matches | Elves win % | Caps E/H | Avg length (s) | 12-15 min | Shorter | Overtime |")
    print("|---|---|---|---|---|---|---|---|")
    tot = collections.Counter()
    for mp in MAPS + ["?"]:
        c = maps.get(mp)
        if not c:
            continue
        tot.update(c)
        print("| %s | %d | %.0f | %d/%d | %.0f | %d | %d | %d |" % (mp, c["n"], 100 * c["E"] / c["n"], c["capsE"], c["capsH"],
              c["t"] / c["n"], c["in"], c["short"], c["ot"]))
    if tot["n"]:
        print("| **All** | %d | %.0f | %d/%d | %.0f | %d | %d | %d |" % (tot["n"], 100 * tot["E"] / tot["n"], tot["capsE"], tot["capsH"],
              tot["t"] / tot["n"], tot["in"], tot["short"], tot["ot"]))
    print("\n| Class | Line | n | Win % (95%% +/-) | Elves n / win %% | Humans n / win %% | K/D | dmg/match |".replace("%%", "%"))
    print("|---|---|---|---|---|---|---|---|")
    names = sorted({k[0] for k in cls}, key=lambda s: (LINE.get(s, s), s))
    for name in names:
        c = cls[(name, None)]
        e = cls.get((name, 0), collections.Counter())
        h = cls.get((name, 1), collections.Counter())
        side = lambda x: "%d / %.0f" % (x["n"], 100 * x["w"] / x["n"]) if x["n"] else "0 / -"
        print("| %s | %s | %d | %.0f +/- %.0f | %s | %s | %.2f | %.0f |" % (name, LINE.get(name, "?"), c["n"], 100 * c["w"] / c["n"],
              ci(c["w"], c["n"]), side(e), side(h), c["k"] / max(c["d"], 1), c["dmg"] / c["n"]))


if __name__ == "__main__":
    main(sys.argv[1:])
