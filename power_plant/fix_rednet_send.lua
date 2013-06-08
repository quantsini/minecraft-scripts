local CHANNEL_BROADCAST = 65535
local function fixed_rednet_send( nRecipient, sMessage, side )
 local transmitted = false
	for n,sSide in ipairs( rs.getSides() ) do
		if rednet.isOpen( sSide ) and (side == nil or sSide == side) then
			peripheral.call( sSide, "transmit", nRecipient, os.getComputerID(), sMessage )
			transmitted = true
		end
	end
if not transmitted then
	error( "No open sides" )
end
return true
end

function fixed_rednet_broadcast( sMessage, side )
	return fixed_rednet_send( CHANNEL_BROADCAST, sMessage, side )
end

rednet.send = fixed_rednet_send
rednet.broadcast = fixed_rednet_broadcast
