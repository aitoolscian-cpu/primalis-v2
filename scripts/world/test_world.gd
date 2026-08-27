extends Node3D
## Step 2 test world. Bakes the navmesh from static colliders at startup so
## the walkable surface always matches whatever obstacles the scene contains.

@onready var _nav_region: NavigationRegion3D = $NavRegion

## Re-carve the walkable surface (e.g. after a completed building gains
## its obstacle collider).
func rebake_navmesh() -> void:
	_nav_region.bake_navigation_mesh(false)

func _ready() -> void:
	_nav_region.bake_navigation_mesh(false)
	# Den gameplay effect: completed shelter slows Primalis hunger growth 10%.
	var den := $Anchors/DenSite as ConstructionProject
	var primalis := $Primalis as PrimalisController
	if den != null and primalis != null:
		den.completed.connect(func() -> void:
			primalis.get_hunger_node().apply_shelter_bonus(0.9))
