extends RefCounted

static func generate(city: Node3D) -> void:
	var deck_scene: PackedScene = preload("res://assets/kenney_city/roads/road-bridge.glb")
	var pillar_scene: PackedScene = preload("res://assets/kenney_city/roads/bridge-pillar.glb")
	for road in city.topology.artery_types:
		if city.topology.artery_types[road] != "bridge": continue
		var vertical: bool = bool(road.x)
		var coordinate: float = road.y
		var width: float = city.road_width + 2 * (city.parking_bay_width + .4 + city.sidewalk_width)
		for segment in city.topology.segments(vertical, coordinate, city.road_visual_extent, city.road_width * .5):
			var along: float = segment.x
			while along < segment.y:
				await city.loading_checkpoint()
				var length: float = minf(16, segment.y - along)
				var center := Vector2(coordinate,along + length*.5) if vertical else Vector2(along + length*.5,coordinate)
				var deck := deck_scene.instantiate() as Node3D
				deck.name = "BridgeDeck"
				deck.set_meta("bridge_artery",true)
				deck.position = Vector3(center.x,city.height_at(center.x,center.y)-.1,center.y)
				deck.scale = Vector3(width,2,length)
				deck.rotation.y = 0.0 if vertical else PI*.5
				city.get_node("HighwayApproaches").add_child(deck,true)
				var pillar := pillar_scene.instantiate() as Node3D
				pillar.name = "BridgePillar"
				var ground: float = city.terrain_height_at(center.x,center.y)
				pillar.position = Vector3(center.x,ground,center.y)
				pillar.scale = Vector3(30,city.bridge_clearance*2,30)
				city.get_node("HighwayApproaches").add_child(pillar,true)
				along += length
