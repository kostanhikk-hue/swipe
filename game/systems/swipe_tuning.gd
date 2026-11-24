class_name SwipeTuning
extends Resource
## M01 feel parameters. Read every frame by the gym (live tuning panel).

@export_range(60.0, 400.0, 5.0) var threshold_x := 180.0        ## px of card offset to commit sell/equip
@export_range(60.0, 400.0, 5.0) var threshold_up := 160.0       ## px up to commit melt
@export_range(200.0, 3000.0, 50.0) var fling_speed := 900.0     ## px/s release speed that commits early
@export_range(0.0, 30.0, 0.5) var max_tilt_deg := 12.0          ## tilt at threshold_x
@export_range(0.05, 0.6, 0.01) var return_time := 0.18          ## spring back
@export_range(800.0, 6000.0, 100.0) var exit_speed_min := 2400.0
@export_range(0.0, 200.0, 5.0) var hitstop_ms := 60.0
@export_range(0.0, 30.0, 0.5) var shake_px := 9.0
@export_range(0.0, 500.0, 10.0) var shake_ms := 180.0
@export_range(1.0, 1.5, 0.01) var punch_scale := 1.2
@export_range(0.1, 0.8, 0.01) var rise_time := 0.28             ## next card rises from the doorway
@export_range(0.05, 0.6, 0.01) var equip_fly_time := 0.22       ## card flies into its slot
@export_range(0.0, 1.0, 1.0) var preview := 1.0                 ## Reigns-like preview while dragging
@export_range(0.0, 1.0, 1.0) var melt_enabled := 1.0
