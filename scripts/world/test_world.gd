extends Node3D
## Step 2 test world. Bakes the navmesh from static colliders at startup so
## the walkable surface always matches whatever obstacles the scene contains.

@onready var _nav_region: NavigationRegion3D = $NavRegion

func _ready() -> void:
	_nav_region.bake_navigation_mesh(false)
