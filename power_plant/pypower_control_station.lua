local pypower = dofile("pypower.lua")
local log = dofile("log.lua")
local reactor = dofile("reactor.lua")

local pypower_control_station = {}
local logger = log.Logger.new("control_station")

-- TODO: build config infrastructure
local POWER_PLANT_SIDE = "top"
local OUTSIDE_WORLD_SIDE = "bottom"
rednet.open(POWER_PLANT_SIDE)
rednet.open(OUTSIDE_WORLD_SIDE)

pypower_control_station.power_nodes = {}

local function activate_node(node_id)
	return reactor.remote_call(node_id, "ACTIVATE_NODE", nil, POWER_PLANT_SIDE)
end

local function deactivate_node(node_id)
	return reactor.remote_call(node_id, "DEACTIVATE_NODE", nil, POWER_PLANT_SIDE)
end

local function node_status(node_id)
	return reactor.remote_call(node_id, "STATUS", nil, POWER_PLANT_SIDE)
end

function pypower_control_station.count_number_running_nodes()
	local running_nodes = 0
	for i, v in ipairs(pypower_control_station.nodes) do
		if v.is_running then
			running_nodes = running_nodes + 1
		end
	end
	return running_nodes
end

function pypower_control_station.on_status(from_id, payload, distance)
	-- pypower_control_station.update_node_list()
	return pypower_control_station.build_status()
end

function pypower_control_station.get_status()
	-- TODO: build an enum?
	local status = 'good'
	if pypower_control_station.broken then
		status = 'bad'
	end
	return status
end

function pypower_control_station.build_status()
	return {
		['status']=pypower_control_station.get_status(),
		['total_nodes']=table.getn(pypower_control_station.nodes),
		['running_nodes']=pypower_control_station.count_number_running_nodes(),
		['id']=os.getComputerID(),
		['name']=os.getComputerLabel(),
	}
end

function pypower_control_station.on_activate(from_id, payload, distance)
	local number_to_activate = payload.number
	deactivate_node()
	if payload.number > table.getn(pypower_control_station.nodes) then
		return {['error']='Number exceeds plant capacity'}
	end
	for i=1,number_to_activate do
		local node = pypower_control_station.nodes[i]
		activate_node(node.id)
	end
	pypower_control_station.update_node_list()
	return pypower_control_station.build_status()
end

function pypower_control_station.update_node_list()
	local nodes = node_status()(0.25)
	if nodes == nil then
		logger:error("Error getting nodes")
	end
	if pypower_control_station.nodes ~= nil then
		if table.getn(pypower_control_station.nodes) ~= table.getn(nodes) then
			pypower_control_station.broken = true
		end
	end
	pypower_control_station.nodes = nodes
end

-- TODO: rename janky variable names
pypower_control_station.nodes = nil
pypower_control_station.broken = false
local function heartbeat()
	-- Polls to check the power plant hasn't exploded
	while true do
		pypower_control_station.update_node_list()
		os.sleep(600)
	end
end

local REQUEST_HANDLERS = {
	['STATION_STATUS']=pypower_control_station.on_status,
	['STATION_ACTIVATE']=pypower_control_station.on_activate,
}

function pypower_control_station.start()
	logger:info("Starting station")
	deactivate_node()
	reactor.start(true, heartbeat, REQUEST_HANDLERS)
end

return pypower_control_station
