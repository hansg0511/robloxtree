#!/usr/bin/env python3
"""Offline, dependency-free crafting balance experiment (NOT live Roblox logic).

Usage: python tools/crafting_balance_sim.py --samples 20000 --seed 42

All material scores, weapon multipliers and class odds below are provisional.
The model intentionally exposes the cheap-dagger efficiency trade-off.
"""

from __future__ import annotations

import argparse
import math
import random
from collections import Counter
from dataclasses import dataclass
from statistics import mean
from typing import Sequence

GLOBAL_MAX_SIZE = 5.0  # Future-game design assumption; current Grove caps at 2x.
STAT_FLOOR = 0.5  # 0% log quality yields 50% of a reference stat before roll.
ROLL_MIN, ROLL_MAX = 0.9, 1.1
GOLDEN_MAX_BONUS = 0.30  # Placeholder bonus; no live Golden combat effect exists.
METAL_BASE = {"Copper": 25.0, "Bronze": 40.0, "Iron": 55.0}
WOOD_BASE = {"Bamboo": 6.0, "Oak": 10.0, "Ironwood": 16.0}

# Damage and attack-rate multipliers define competing weapon class identities.
# Reach is not incorporated into DPS: in play it matters for target acquisition.
CLASS_STATS = {
    "Dagger": {"damage": 0.55, "attacks_per_second": 2.20, "reach": 0.75},
    "Axe": {"damage": 1.25, "attacks_per_second": 1.20, "reach": 1.00},
    "Battlehammer": {"damage": 3.60, "attacks_per_second": 0.70, "reach": 1.40},
}

# Piecewise-linear count -> class chance anchors. Illustrative, not agreed odds.
# Any quantity >= 20 guarantees the heavy class in this first simple model.
ODDS_ANCHORS = (
    (1, (1.00, 0.00, 0.00)),
    (3, (0.80, 0.20, 0.00)),
    (5, (0.35, 0.65, 0.00)),
    (8, (0.10, 0.70, 0.20)),
    (10, (0.02, 0.38, 0.60)),
    (15, (0.00, 0.15, 0.85)),
    (20, (0.00, 0.00, 1.00)),
)
CLASSES = tuple(CLASS_STATS)


@dataclass(frozen=True)
class Log:
    species: str
    size: float
    golden: bool = False


@dataclass(frozen=True)
class Result:
    weapon_class: str
    material_quality: float
    mutation_quality: float
    damage: float
    attacks_per_second: float
    reach: float
    golden_bonus: float

    @property
    def dps(self) -> float:
        return self.damage * self.attacks_per_second * (1.0 + self.golden_bonus)

    def seconds_to_chop(self, hp: float) -> float:
        """First hit occurs after one swing interval (no travel time modeled)."""
        if hp <= 0:
            raise ValueError("tree HP must be positive")
        return math.ceil(hp / (self.damage * (1.0 + self.golden_bonus))) / self.attacks_per_second


def quality(size: float) -> float:
    if not math.isfinite(size) or size <= 0:
        raise ValueError("log size must be finite and positive")
    return max(0.0, min(1.0, size / GLOBAL_MAX_SIZE))


def quality_factor(q: float) -> float:
    if not 0.0 <= q <= 1.0:
        raise ValueError("quality must be in [0,1]")
    return STAT_FLOOR + (1.0 - STAT_FLOOR) * q


def weapon_odds(log_count: int) -> dict[str, float]:
    if isinstance(log_count, bool) or not isinstance(log_count, int) or log_count < 1:
        raise ValueError("log count must be a positive integer")
    if log_count >= ODDS_ANCHORS[-1][0]:
        return dict(zip(CLASSES, ODDS_ANCHORS[-1][1]))
    for (count0, odds0), (count1, odds1) in zip(ODDS_ANCHORS, ODDS_ANCHORS[1:]):
        if count0 <= log_count <= count1:
            portion = (log_count - count0) / (count1 - count0)
            return dict(zip(CLASSES, (a + (b - a) * portion for a, b in zip(odds0, odds1))))
    raise AssertionError("unreachable odds interval")


def draw_class(log_count: int, rng: random.Random) -> str:
    odds = weapon_odds(log_count)
    u = rng.random()
    cumulative = 0.0
    for name, p in odds.items():
        cumulative += p
        if u < cumulative:
            return name
    return CLASSES[-1]  # Protect against floating-point summation error.


def forge(metal: str, logs: Sequence[Log], rng: random.Random,
          forced_class: str | None = None) -> Result:
    if metal not in METAL_BASE:
        raise ValueError(f"unknown metal {metal!r}")
    if not logs:
        raise ValueError("at least one log required")
    for item in logs:
        if item.species not in WOOD_BASE:
            raise ValueError(f"unknown species {item.species!r}")
    q = mean(quality(item.size) for item in logs)
    wood = mean(WOOD_BASE[item.species] for item in logs)
    mutation_q = sum(quality(item.size) for item in logs if item.golden) / len(logs)
    weapon_class = forced_class if forced_class is not None else draw_class(len(logs), rng)
    if weapon_class not in CLASS_STATS:
        raise ValueError(f"unknown class {weapon_class!r}")
    profile = CLASS_STATS[weapon_class]
    q_scale = quality_factor(q)
    reference = METAL_BASE[metal] + wood
    # Each eligible numeric stat gets an independent forge roll; quality applies
    # to every one. Mutations are separately diluted by unmutated materials.
    damage = reference * profile["damage"] * q_scale * rng.uniform(ROLL_MIN, ROLL_MAX)
    speed = profile["attacks_per_second"] * q_scale * rng.uniform(ROLL_MIN, ROLL_MAX)
    reach = profile["reach"] * q_scale * rng.uniform(ROLL_MIN, ROLL_MAX)
    golden_bonus = GOLDEN_MAX_BONUS * mutation_q * rng.uniform(ROLL_MIN, ROLL_MAX) if mutation_q else 0.0
    return Result(weapon_class, q, mutation_q, damage, speed, reach, golden_bonus)


def summary(results: Sequence[Result], n_logs: int) -> dict:
    counts = Counter(result.weapon_class for result in results)
    return {
        "class_odds": {name: counts[name] / len(results) for name in CLASSES},
        "quality": mean(r.material_quality for r in results),
        "dps": mean(r.dps for r in results),
        "dps_per_log": mean(r.dps for r in results) / n_logs,
        "time_20hp": mean(r.seconds_to_chop(20) for r in results),
        "time_100hp": mean(r.seconds_to_chop(100) for r in results),
        "time_400hp": mean(r.seconds_to_chop(400) for r in results),
        "reach": mean(r.reach for r in results),
        "mutation_bonus": mean(r.golden_bonus for r in results),
    }


def simulate_case(n_logs: int, size: float, species: str, samples: int,
                  seed: int, forced_class: str | None = None,
                  golden_count: int = 0) -> dict:
    if golden_count < 0 or golden_count > n_logs:
        raise ValueError("invalid Golden log count")
    materials = [Log(species, size, i < golden_count) for i in range(n_logs)]
    rng = random.Random(seed)
    results = [forge("Copper", materials, rng, forced_class) for _ in range(samples)]
    return summary(results, n_logs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=20000,
                        help="independent forging rolls per scenario")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if not 1 <= args.samples <= 500000:
        parser.error("--samples must be in [1,500000]")

    print("CRAFTING BALANCE PROTOTYPE — purely offline; NO LIVE FORGE CHANGES")
    print(f"Samples/scenario: {args.samples:,}; seed: {args.seed}")
    print(f"Global max log size: {GLOBAL_MAX_SIZE}x; stat floor: {STAT_FLOOR:.0%}; independent rolls: {ROLL_MIN:.0%}..{ROLL_MAX:.0%}")
    print("\nCOUNT-BASED WEAPON ODDS (illustrative, no rate locked)")
    print("Logs |  Dagger  |    Axe   |  Hammer ")
    for n in (1, 3, 5, 8, 10, 15, 20, 50):
        o = weapon_odds(n)
        print(f"{n:>4} | {o['Dagger']:>7.1%} | {o['Axe']:>7.1%} | {o['Battlehammer']:>7.1%}")

    print("\nCONTROLLED COMPARISON: SAME METAL, SAME SPECIES, SAME LOG QUALITY")
    print("Class        | Logs | Q     | Mean DPS | DPS/log | 20HP sec | 100HP sec | 400HP sec")
    rows = [("Dagger", 1), ("Axe", 5), ("Battlehammer", 10)]
    for size in (1.0, 4.0):
        for weapon_class, n in rows:
            r = simulate_case(n, size, "Ironwood", args.samples, args.seed,
                              forced_class=weapon_class)
            print(f"{weapon_class:<12} | {n:>4} | {r['quality']:>5.0%} | {r['dps']:>8.1f} | {r['dps_per_log']:>7.1f} | {r['time_20hp']:>8.2f} | {r['time_100hp']:>9.2f} | {r['time_400hp']:>9.2f}")

    print("\nREAL FORGE MIXES: WEAPON CLASS IS ROLLED FROM LOG COUNT")
    print("Offering                     | Q     | Dagger | Axe    | Hammer | Mean DPS | DPS/log")
    for title, n, species, size in (
        ("1x elite Ironwood", 1, "Ironwood", 4.0),
        ("10x ordinary Oak", 10, "Oak", 1.0),
        ("10x elite Ironwood", 10, "Ironwood", 4.0),
        ("20x ordinary Oak", 20, "Oak", 1.0),
    ):
        r = simulate_case(n, size, species, args.samples, args.seed)
        o = r['class_odds']
        print(f"{title:<28} | {r['quality']:>5.0%} | {o['Dagger']:>5.0%}  | {o['Axe']:>5.0%} | {o['Battlehammer']:>6.0%} | {r['dps']:>8.1f} | {r['dps_per_log']:>7.1f}")

    print("\nMUTATION DILUTION (Golden potency is its own quality-weighted stat)")
    for count in (0, 1, 2, 5, 10):
        r = simulate_case(10, 4.0, "Ironwood", args.samples, args.seed,
                          forced_class="Battlehammer", golden_count=count)
        print(f"{count:>2} Golden of 10 elite logs => ~{r['mutation_bonus']:.2%} bonus;"
              f" quality {r['quality']:.0%}")
    print("\nNOTE: forced-class rows isolate combat balance; the actual forge uses the odds above.")
    print("Reach, target travel, AoE abilities, progression unlocks and market value are NOT included in DPS.")


if __name__ == "__main__":
    main()
