"""Run with: python -m unittest discover -s tests -p 'test_crafting_balance_sim.py'"""

import math
import sys
import unittest
from pathlib import Path
from random import Random

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

import crafting_balance_sim as sim


class ScriptedRng:
    def __init__(self, rolls):
        self.rolls = iter(rolls)

    def uniform(self, minimum, maximum):
        roll = next(self.rolls)
        assert minimum <= roll <= maximum
        return roll


class CraftingBalanceTests(unittest.TestCase):
    def test_absolute_quality_not_relative_to_tree_genetics(self):
        self.assertEqual(sim.quality(0.5), 0.1)
        self.assertEqual(sim.quality(5), 1)
        self.assertEqual(sim.quality(6), 1)
        with self.assertRaises(ValueError):
            sim.quality(float("nan"))

    def test_low_quality_floor_and_full_quality_reference(self):
        self.assertEqual(sim.quality_factor(0), sim.STAT_FLOOR)
        self.assertEqual(sim.quality_factor(1), 1)
        self.assertAlmostEqual(sim.quality_factor(0.2), 0.6)

    def test_weapon_odds_are_distributions_for_any_positive_count(self):
        for count in range(1, 201):
            odds = sim.weapon_odds(count)
            self.assertAlmostEqual(sum(odds.values()), 1)
            self.assertTrue(all(0 <= value <= 1 for value in odds.values()))
        self.assertEqual(sim.weapon_odds(1)["Dagger"], 1)
        self.assertEqual(sim.weapon_odds(10)["Battlehammer"], 0.60)
        self.assertEqual(sim.weapon_odds(50)["Battlehammer"], 1)
        with self.assertRaises(ValueError):
            sim.weapon_odds(0)

    def test_independent_damage_speed_reach_rolls(self):
        # The 1x Oak has q=.2, so the quality factor is .6.
        result = sim.forge("Copper", [sim.Log("Oak", 1)],
                           ScriptedRng([0.9, 1.1, 1.0]), "Dagger")
        self.assertAlmostEqual(result.material_quality, 0.2)
        self.assertAlmostEqual(result.damage, 35 * 0.55 * 0.6 * 0.9)
        self.assertAlmostEqual(result.attacks_per_second, 2.2 * 0.6 * 1.1)
        self.assertAlmostEqual(result.reach, 0.75 * 0.6)
        self.assertEqual(result.golden_bonus, 0)

    def test_material_species_and_quality_are_averaged(self):
        logs = [sim.Log("Oak", 1), sim.Log("Ironwood", 4)]
        result = sim.forge("Copper", logs, ScriptedRng([1, 1, 1]), "Axe")
        self.assertAlmostEqual(result.material_quality, 0.5)
        base = 25 + (10 + 16) / 2
        self.assertAlmostEqual(result.damage, base * 1.25 * 0.75)

    def test_mutation_is_diluted_and_quality_applied_once(self):
        logs = [sim.Log("Ironwood", 4, i < 2) for i in range(10)]
        result = sim.forge("Copper", logs, ScriptedRng([1, 1, 1, 1]), "Battlehammer")
        self.assertAlmostEqual(result.material_quality, 0.8)
        self.assertAlmostEqual(result.mutation_quality, 2 * 0.8 / 10)
        self.assertAlmostEqual(result.golden_bonus, 0.30 * 0.16)

    def test_fixed_seed_reproduces_forge_roll(self):
        logs = [sim.Log("Oak", 1.5) for _ in range(10)]
        self.assertEqual(sim.forge("Bronze", logs, Random(42)),
                         sim.forge("Bronze", logs, Random(42)))

    def test_random_class_guaranteed_for_one_or_twenty(self):
        for count, expected in [(1, "Dagger"), (20, "Battlehammer")]:
            logs = [sim.Log("Bamboo", 1) for _ in range(count)]
            for seed in (1, 2, 3, 4):
                self.assertEqual(sim.forge("Copper", logs, Random(seed)).weapon_class, expected)

    def test_tree_hp_model_requires_positive_hp(self):
        result = sim.forge("Copper", [sim.Log("Oak", 1)], Random(42))
        self.assertGreater(result.seconds_to_chop(100), 0)
        with self.assertRaises(ValueError):
            result.seconds_to_chop(0)

    def test_bad_materials_fail(self):
        with self.assertRaises(ValueError):
            sim.forge("Copper", [], Random(42))
        with self.assertRaises(ValueError):
            sim.forge("Copper", [sim.Log("Obsidian", 1)], Random(42))
        with self.assertRaises(ValueError):
            sim.forge("Lead", [sim.Log("Oak", 1)], Random(42))
        with self.assertRaises(ValueError):
            sim.forge("Copper", [sim.Log("Oak", 1)], Random(42), "Spear")


if __name__ == "__main__":
    unittest.main()
