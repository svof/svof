-- this is a temporary thing until the cure/line get replaced: do NOT follow this bad example!

local lastline = getLines(getLineNumber()-1, getLineNumber())[1]

moveCursor(0, getLineNumber()-1)
deleteLine()
moveCursorEnd()

tempTimer(0, function() svo.valid.passive_cure() feedTriggers(lastline.."\n") end)

send("\n")