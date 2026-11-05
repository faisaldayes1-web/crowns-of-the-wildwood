"""Check a Team Deathmatch bot match log (claude-faisal/crowns-tdm 2026-11-04).

    python3 tools/tdm_bot_check.py ci-logs/tdm-bots-map0.log

The match must have run as TDM to a result, the bots must have fought (kills
on both sides' stat lines), and the team score must equal every fall in the
match: each enemy knocked down or killed is exactly one point.
"""
import re
import sys


def main(path: str) -> int:
    text = open(path, encoding="utf-8", errors="replace").read()
    fails = []
    m = re.search(r"^RESULT winner=(\S+) score=(\d+)-(\d+) t=(\d+) .*mode=(\w+) sudden=(\w+)", text, re.M)
    if not m:
        print("FAIL no RESULT line with mode=")
        return 1
    winner, s0, s1, t, mode, sudden = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), m.group(5), m.group(6)
    if mode != "tdm":
        fails.append("mode is %s, not tdm" % mode)
    stats = re.findall(r"^STAT team=(\d) .* kills=(\d+) deaths=(\d+)", text, re.M)
    if len(stats) < 2:
        fails.append("no STAT lines")
    deaths = [0, 0]
    kills = 0
    for team, k, d in stats:
        deaths[int(team)] += int(d)
        kills += int(k)
    if kills == 0:
        fails.append("the bots never killed anyone")
    # Team 0 scores for every Human (team 1) fall, and the other way round.
    if s0 != deaths[1] or s1 != deaths[0]:
        fails.append("score %d-%d does not match the falls %d-%d" % (s0, s1, deaths[1], deaths[0]))
    if winner != "Draw" and s0 == s1:
        fails.append("a winner on a tied score")
    for f in fails:
        print("FAIL " + f)
    print("TDM bot match: winner=%s score=%d-%d t=%d sudden=%s kills=%d: %d failure(s)" % (winner, s0, s1, t, sudden, kills, len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
