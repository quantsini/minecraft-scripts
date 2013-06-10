-- Defer is an object that contains a "promise" a value will be given to you. By itself, it may or may not contain the object.
-- Calls on instances of Defer objects will block until the value is available, or until a given timeout is reached.
local Defer = {}

Defer.__index = Defer
function Defer:__call(timeout_sec)
	return self.block(timeout_sec)
end

function Defer.new(callback_identifier, is_single_shot)
	local function defer_function(timeout_sec)
		if timeout_sec == nil then
			timeout_sec = 5
		end
		local return_value = {}	
		local function gather()
			while true do
				local event, return_val = os.pullEvent(callback_identifier)
				table.insert(return_value, return_val)
				if is_single_shot then
					break
				end
			end
		end
		local function timeout()
			local current_timer_id = nil
			local timer_id = os.startTimer(timeout_sec)
			while true do
				local event, current_timer_id = os.pullEvent('timer')
				if timer_id == current_timer_id then
					break
				end
			end
		end
		parallel.waitForAny(gather, timeout)
		if is_single_shot then
			return_value = return_value[1]
		end
		return return_value
	end
	return setmetatable({['block']=defer_function}, Defer)
end

return Defer
