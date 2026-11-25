class_name CombatTuning
extends Resource
## M03 combat rules and feel.

@export_range(10.0, 400.0, 5.0) var armor_k := 100.0           ## damage × K/(armor+K)
@export_range(1.0, 4.0, 0.05) var crit_mult := 2.0
@export_range(0.0, 90.0, 1.0) var block_cap := 60.0            ## % max block chance
@export_range(5.0, 60.0, 1.0) var time_limit := 30.0           ## s; after it the enemy enrages
@export_range(1.0, 4.0, 0.25) var boss_time_mult := 2.0
@export_range(10.0, 300.0, 5.0) var hero_base_hp := 100.0
@export_range(0.0, 20.0, 0.5) var hero_base_dmg := 6.0           ## fists; weapon damage adds on top
@export_range(0.2, 2.0, 0.05) var fist_speed := 0.9             ## attacks/s without a weapon
@export_range(0, 20, 1) var tutorial_depth := 5                ## first N enemies are guaranteed wins
@export_range(0.05, 1.0, 0.05) var tutorial_mult := 0.3          ## their HP/damage/armor share
@export_range(0, 20, 1) var ramp_depths := 6                   ## after the tutorial, strength ramps to 100% over N depths
@export_range(0.0, 2.0, 0.05) var hero_first_delay := 0.3
@export_range(0.0, 2.0, 0.05) var enemy_first_delay := 0.7
@export_range(0.0, 1.0, 0.05) var heal_after_win := 0.2       ## passive heal after each win
@export_range(0.0, 0.5, 0.01) var depth_hp := 0.12             ## enemy HP +% per depth (compound)
@export_range(0.0, 0.5, 0.01) var depth_dmg := 0.10            ## enemy damage +% per depth (compound)
@export_range(0.0, 0.2, 0.005) var depth_armor := 0.04         ## enemy armor +% per depth (linear)
@export_range(0.0, 0.3, 0.01) var depth_loot := 0.08           ## item stats +% per depth
@export_range(0.0, 150.0, 5.0) var hit_hitstop_ms := 20.0
@export_range(0.0, 250.0, 5.0) var crit_hitstop_ms := 80.0
@export_range(0.0, 30.0, 0.5) var hit_shake_px := 4.0
@export_range(0.0, 40.0, 0.5) var crit_shake_px := 12.0
@export_range(0.1, 3.0, 0.05) var fight_speed := 1.0
