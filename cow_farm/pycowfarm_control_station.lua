local log = dofile("log.lua")
local reactor = dofile("reactor.lua")

local pycowfarm_control_station = {}
local logger = log.Logger.new("control_station")

local COW_FARM_SIDE = "right"
local OUTSIDE_WORLD_SIDE = "top"
rednet.open(COW_FARM_SIDE)
rednet.open(OUTSIDE_WORLD_SIDE)

pycowfarm_control_station.nodes = {}

local function open(node_id)
	reactor.remote_call(node_id, "OPEN", nil, COW_FARM_SIDE)
end

local function close(node_id)
	return reactor.remote_call(node_id, "CLOSE", nil, COW_FARM_SIDE)
end

local function node_status(node_id)
	return reactor.remote_call(node_id, "STATUS", nil, COW_FARM_SIDE)
end

function pycowfarm_control_station.count_number_open_nodes()
	local running_nodes = 0
	for i, v in ipairs(pycowfarm_control_station.nodes) do
		if v.is_open then
			running_nodes = running_nodes + 1
		end
	end
	return running_nodes
end

function pycowfarm_control_station.build_status()
	return {
		['station_type']='cow_farm',
		['total_nodes']=table.getn(pycowfarm_control_station.nodes),
		['nodes_open']=pycowfarm_control_station.count_number_open_nodes(),
		['id']=os.getComputerID(),
		['name']=os.getComputerLabel(),
		['available_methods']={'STATION_OPEN_COW_TRAPDOOR', 'STATION_STATUS'}
	}
end

function pycowfarm_control_station.update_node_list()
	local nodes = node_status()(0.25)
	if nodes == nil then
		logger:error("Error getting nodes")
	end
	pycowfarm_control_station.nodes = nodes
end

-- TODO: rename janky variable names
pycowfarm_control_station.nodes = nil
pycowfarm_control_station.broken = false
local function heartbeat()
	-- Polls to check the power plant hasn't exploded
	while true do
		pycowfarm_control_station.update_node_list()
		os.sleep(600)
	end
end

function pycowfarm_control_station.on_open(from_id, payload, distance)
	local number_to_activate = payload.number
	close()
	if payload.number > table.getn(pycowfarm_control_station.nodes) then
		return {['error']='Number exceeds cow farm capacity'}
	end
	for i=1,number_to_activate do
		local node = pycowfarm_control_station.nodes[i]
		open(node.id)
	end
	pycowfarm_control_station.update_node_list()
	return pycowfarm_control_station.build_status()
end

function pycowfarm_control_station.on_status(from_id, payload, distance)
	-- pycowfarm_control_station.update_node_list()
	return pycowfarm_control_station.build_status()
end

local REQUEST_HANDLERS = {
	['STATION_STATUS']=pycowfarm_control_station.on_status,
	['STATION_OPEN_COW_TRAPDOOR']=pycowfarm_control_station.on_open,
}

pycowfarm_control_station.nodes = nil
function pycowfarm_control_station.start()
	logger:info("Starting station")
	close()
	reactor.start(true, heartbeat, REQUEST_HANDLERS)
end

return pycowfarm_control_station
