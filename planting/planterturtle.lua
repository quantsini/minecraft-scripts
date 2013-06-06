STATES = {
	IDLE = "IDLE",
	START = "START",
	CALIBRATE = "CALIBRATE",
	NOT_ENOUGH_FUEL = "NOT_ENOUGH_FUEL",
	NOT_ENOUGH_SEEDS = "NOT_ENOUGH_SEEDS",
	PLANTING = "PLANTING",
	RETURNING_HOME = "RETURNING_HOME",
}

PlanterTurtle = {
	size = vector.new(0, 0, 0),
	calibrated = false,
	--position = vector.new(0, 0, 0),
	state = STATES.IDLE,
	turtle = nil,
	should_turn_left = false,
}

function PlanterTurtle:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
 	return o
end

function PlanterTurtle:start()
	if not self.calibrated then
		self:calibrate()
	end
	while self.state ~= STATES.IDLE do
		self:_tick()
	end
end

function PlanterTurtle:calibrate()
	if self.calibrated then
		return 0
	end
 self:_next_state(STATES.CALIBRATE)
end

function PlanterTurtle:_tick()
	if self.state == STATES.IDLE then
		self:_do_idle()
	elseif self.state == STATES.START then
 		self:_do_start()
	elseif self.state == STATES.CALIBRATE then
		self:_do_calibrate()
	elseif self.state == STATES.NOT_ENOUGH_FUEL then
		self:_do_not_enough_fuel()
	elseif self.state == STATES.NOT_ENOUGH_SEEDS then
		self:_do_not_enough_seeds()
	elseif self.state == STATES.PLANTING then
		self:_do_planting()	
	elseif self.state == STATES.RETURNING_HOME then
		self:_do_returning_home()
	else
		print("Unknown state "..self.state)
	end
end

function PlanterTurtle:_next_state(next_state)
	print("Previous state "..self.state)
	print("Next state "..next_state)
	self.state = next_state
	-- TODO: pre/post state functions
end

function PlanterTurtle:_do_not_enough_fuel()
	if not self:_has_enough_fuel() then
		print("Not enough fuel, please place fuel in slot 1. "..self.turtle.getFuelLevel().."/"..self:_maximum_number_steps())
		self.turtle.select(1)
		self.turtle.refuel()
		os.sleep(5)
	else
		self._next_state(STATES.START)
	end
end

function PlanterTurtle:_do_not_enough_seeds()
	if not self:_has_enough_seeds() then
		print("Not enough seeds. "..self:num_seeds().."/"..self:_minimum_number_of_seeds()..".")
		os.sleep(5)
	else
		self:_next_state(STATES.START)
	end
end

function PlanterTurtle:_do_calibrate()
	-- TODO: do calibration
	self.size = vector.new(6, 0, 8)
	self:_next_state(STATES.START)
end

function PlanterTurtle:num_seeds()
	local count = 0
		for slot = 1,16 do
			self.turtle.select(slot)
			if self.turtle.compareTo(16) == true then
				count = count + self.turtle.getItemCount(slot)
			end
		end
	return count
end

function PlanterTurtle:_do_planting()
	for xherp = 1, self.size.x * self.size.z - 1 do
		self:_plant_seed()
		self:_move()
	end
 self:_next_state(STATES.RETURNING_HOME)
end

function PlanterTurtle:_move()
	if self.turtle.detect() then
		self:_turn()
	else
		self.turtle.forward()
	end
end

function PlanterTurtle:_turn()
	if self.should_turn_left == true then
		self.turtle.turnLeft()
		self.turtle.forward()
		self.turtle.turnLeft()
		self.should_turn_left = false
	else
		self.turtle.turnRight()
		self.turtle.forward()
		self.turtle.turnRight()
		self.should_turn_left = true
	end
end

function PlanterTurtle:_plant_seed()
	local excess = turtle.getItemCount(16) - 1
	for slot=1,15 do
		turtle.select(slot)
		if excess ~= 0 then
			turtle.select(16)
			turtle.transferTo(slot, excess)
			turtle.select(slot)
		end

		if turtle.compareTo(16) then
			turtle.placeDown()
			break
		end
	end
end

function PlanterTurtle:_maximum_number_steps()
	return self.size.x * self.size.z - 1
end

function PlanterTurtle:_minimum_number_of_seeds()
	return self.size.x * self.size.z
end

function PlanterTurtle:_has_enough_fuel()
	return self.turtle.getFuelLevel() >=  self:_maximum_number_steps()
end

function PlanterTurtle:_has_enough_seeds()
	return self:num_seeds() >= self:_minimum_number_of_seeds()
end

function PlanterTurtle:_do_start()
	if not self:_has_enough_fuel() then
 		self:_next_state(STATES.NOT_ENOUGH_FUEL)
	elseif not self:_has_enough_seeds() then
		self:_next_state(STATES.NOT_ENOUGH_SEEDS)
	else
		self:_next_state(STATES.PLANTING)
	end
end

function PlanterTurtle:_do_returning_home()
	self._plant_seed()

	turtle.turnRight()
	while not turtle.detect() do
		turtle.forward()
	end
	turtle.turnRight()
	self:_next_state(STATES.IDLE)
end