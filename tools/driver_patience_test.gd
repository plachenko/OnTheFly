extends SceneTree

func _initialize() -> void:
	var driver = load("res://traffic_car.gd").new()
	driver.patience_depletion_rate = 20.0
	driver.patience_recovery_rate = 5.0
	driver.update_patience(true, 2.0)
	assert(is_equal_approx(driver.patience_ratio, 0.6))
	driver.update_patience(false, 1.0)
	assert(is_equal_approx(driver.patience_ratio, 0.65))
	driver.update_patience(true, 100.0)
	assert(driver.patience_ratio == 0.0)
	driver.update_patience(false, 0.1)
	assert(driver.patience_ratio > 0.0 and driver.patience_ratio < 0.01)
	driver.update_patience(false, 100.0)
	assert(driver.patience_ratio == 1.0)
	driver.free()
	print("DRIVER PATIENCE PASS: depletion, normalized ratio, gradual recovery, zero/full limits")
	quit()
