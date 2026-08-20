function svo_events(...)
	local s,m = pcall(svo.events, ...)
	if not s then display(m) end
end