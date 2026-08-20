svo.riftline()
svo.prompttrigger("rift contents", function()
  if not getLines(getLineNumber()-1, getLineNumber())[1]:find("MORE") then
    local msg

    if svo.me.parsingrift == 'herb' then
      msg = "Herb rift stats updated."
    elseif svo.me.parsingrift == 'mineral' then
      msg = "Mineral rift stats updated."
    elseif svo.me.parsingrift == 'all' then
      msg = "Herb and mineral rift stats updated."
    else
      -- nothing to say?
      svo.me.parsingrift = nil; return
    end

    svo.me.parsingrift = nil

    setTriggerStayOpen("svo Rift", 0)
    moveCursor(0, getLineNumber()-1)

    if getCurrentLine() ~= '' then
     echo'\n' svo.echof(msg)
    else
      svo.itf("  "..msg)
    end

    moveCursorEnd()
    if svo.temprift then killTrigger(svo.temprift); svo.temprift = nil end
  end
end)