@tool
extends RefCounted

static func stick(value: Vector2, deadzone: float) -> Vector2:
	var length := minf(value.length(), 1.0)
	if length <= deadzone:
		return Vector2.ZERO
	return value.normalized() * (length - deadzone) / (1.0 - deadzone)

static func fly(pose: Transform3D, movement: Vector2, look: Vector2, vertical: float, speed: float, delta: float) -> Transform3D:
	var angles := pose.basis.get_euler()
	angles.y -= look.x * 2.0 * delta
	angles.x = clampf(angles.x - look.y * 2.0 * delta, -PI * 0.495, PI * 0.495)
	angles.z = 0.0
	pose.basis = Basis.from_euler(angles)
	var direction := pose.basis.x * movement.x + pose.basis.z * movement.y + Vector3.UP * vertical
	pose.origin += direction.limit_length() * speed * delta
	return pose

static func orbit(pose: Transform3D, center: Vector3, movement: Vector2, look: Vector2, speed: float, delta: float) -> Transform3D:
	var offset := pose.origin - center
	var radius := maxf(offset.length(), 0.5)
	var yaw := atan2(offset.x, offset.z) - (look.x + movement.x) * 2.0 * delta
	var pitch := asin(clampf(offset.y / radius, -1.0, 1.0)) + look.y * 2.0 * delta
	pitch = clampf(pitch, -PI * 0.49, PI * 0.49)
	radius = maxf(0.5, radius + movement.y * speed * delta)
	pose.origin = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * radius
	return pose.looking_at(center)
