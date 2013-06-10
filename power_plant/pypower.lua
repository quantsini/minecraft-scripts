local reactor = dofile("reactor.lua")
local pypower = {}

function pypower.list_stations(deferred)
	local status = reactor.remote_call(nil, "STATION_STATUS")
	if not deferred then
		status = status(0.5)
	end
	return status
end

function pypower.status(recipient, deferred)
	local status = reactor.remote_call(recipient, "STATION_STATUS")
	if not deferred then
		status = status(0.5)
	end
	return status
end

function pypower.activate(recipient, num_stations, deferred)
	local status = reactor.remote_call(recipient, "STATION_ACTIVATE_POWER_NODE", {['number']=tonumber(num_stations)})
	if not deferred then
		status = status(0.5)
	end
	return status
end

function pypower.shutdown(recipient, deferred)
	return pypower.activate(recipient, 0, deferred)
end

return pypower