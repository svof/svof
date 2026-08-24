function svo_enableCommChannel()
	-- register after GMCP is enabled. gmod doesn't re-register atm on restart
    sendGMCP([[Core.Supports.Add ["Comm.Channel 1"] ]])
end