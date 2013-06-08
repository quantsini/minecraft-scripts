-- RPC implemented using the Reactor Design Pattern.
-- Handles async and sync calls.
-- Seems like overkill for minecraft? probably.

-- Fixes rednet so we can send on _all_ modems
dofile("fix_rednet_send.lua")

local log = dofile("log.lua")
local Defer = dofile("defer.lua")

local reactor = {}

local logger = log.Logger.new("reactor")
local __callback_identifier = 0
reactor.EVENT_NAME_SENTINEL = '_DISPATCH'

local function get_callback_identifier()
	-- Used for identifying what callbacks are mapped to what return values
	-- TODO: find a better way?
	__callback_identifier = __callback_identifier + 1
	return reactor.EVENT_NAME_SENTINEL..__callback_identifier
end

function reactor._send_table(recipient, table, side)
	-- Sends a table to a recipient. nil broadcasts to all.
	-- TODO: abstract side?
	if recipient == nil then
		return rednet.broadcast(table, side)
	end
	return rednet.send(tonumber(recipient), table, side)
end

function reactor.remote_call(recipient, event_name, payload, side)
	-- Invokes an RPC to a recipient. Returns a promise object
	-- similar to jQuery's Defer object or gevent's AsyncResult object.
	-- When you call the promise object, it'll block until the RPC is done.
	-- Returns whatever the RPC returned. Useful for idempotent requests
	-- (such as setting a config file on a remote computer.)
	logger:info("Transmitting "..event_name.." to "..tostring(recipient))
	local callback_identifier = get_callback_identifier()

	-- TODO: support fininte number of recipients
	local is_single_shot = recipient ~= nil
	local blob = {
		['event_name']=event_name,
		['payload']=payload,
		['callback_identifier']=callback_identifier,
	}
	if not reactor._send_table(recipient, blob, side) then
		logger:error("Failed to send table")
	end
	return Defer.new(callback_identifier, is_single_shot)
end

function reactor.capture_rednet()
	local event, from_id, message, distance = os.pullEvent("rednet_message")	
	local parameters = {
		['from_id']=from_id,
		['distance']=distance,
		['payload']=message.payload,
		['event_name']=message.event_name,
		['callback_identifier']=message.callback_identifier,
	}
	logger:info("Dispatching "..message.event_name.." for "..from_id)
	os.queueEvent(reactor.EVENT_NAME_SENTINEL.."_"..message.event_name, parameters)
end

local function handle_callback_return(from_id, payload, distance)
	logger:info("Handling callback for "..from_id)
	local callback_identifier = payload.callback_identifier
	local return_value = payload.return_value
	os.queueEvent(callback_identifier, return_value)
end

function reactor.dispatch_event_factory(event_name, callback_func)
	local function event_dispatcher()
		while true do
			local event, parameters = os.pullEvent(reactor.EVENT_NAME_SENTINEL.."_"..event_name)
			local return_value = callback_func(parameters.from_id, parameters.payload, parameters.distance)

			-- TODO: remote this hack
			if callback_func ~= handle_callback_return then
				logger:info("Sending return value to "..parameters.from_id)
				local response = {
					['callback_identifier']=parameters.callback_identifier,
					['return_value']=return_value,
				}
				reactor.remote_call(parameters.from_id, "__CALLBACK", response)
			end
		end
	end
	return event_dispatcher
end

function reactor.build_dispatchers(request_handlers)
	local dispatchers = {}
	for request_handler_name, request_handler in pairs(request_handlers) do
		local dispatcher = reactor.dispatch_event_factory(request_handler_name, request_handler)
		table.insert(dispatchers, dispatcher)
	end
	return dispatchers
end


function reactor.listen_on_rednet()
	while true do
		reactor.capture_rednet()
	end
end

function reactor.start(logging_enabled, main_func, request_handlers)
	if request_handlers == nil then
		request_handlers = {}
	end
	logger:toggle(logging_enabled)
	logger:info("Starting reactor")

	-- special callback return dispatcher
	request_handlers["__CALLBACK"] = handle_callback_return

	local dispatch_functions = reactor.build_dispatchers(request_handlers)

	if main_func == nil then
		-- Runs in daemon mode
		parallel.waitForAll(reactor.listen_on_rednet, unpack(dispatch_functions))
	else
		-- Run until the end of main_func
		parallel.waitForAny(reactor.listen_on_rednet, main_func, unpack(dispatch_functions))
	end
end

return reactor
