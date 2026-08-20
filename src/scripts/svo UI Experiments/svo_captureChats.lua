-- magical chat capture that doesn't require any triggers!
-- made for Svo
svo.ui = svo.ui or {}

function svo_captureChats()
    if not svo.ui.chat then return end

    tempLineTrigger(0,1,[[
        if isPrompt() then return end
		selectCurrentLine()
		copy()

		if string.starts(line, "(Party)") then svo.ui.chat:Append("Party")
		else svo.ui.chat:Append("All") end
]])
end