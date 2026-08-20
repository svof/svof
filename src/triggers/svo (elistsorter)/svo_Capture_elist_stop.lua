if not string.find(getLines(getLineNumber()-1, getLineNumber())[1], "^Vial") then
  setTriggerStayOpen("svo Capture elist/elist2/venomlist", 0)

  svo.es_captured(svo.parsing_vlist)
  send("config pagelength "..(svo.conf.pagelength >= 20 and svo.conf.pagelength or 20), false)

  svo.gag_list = nil
end