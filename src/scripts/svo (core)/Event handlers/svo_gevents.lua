function svo_gevents(...)
	local s,m = pcall(svo.gevents, ...)
	if not s then display(m) end
end