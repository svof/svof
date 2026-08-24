svo.cpp = svo.cpp or {}

function svo.cpp.show_exits()
  if not (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.exits) then return "" end

  local list = svo.keystolist(gmcp.Room.Info.exits)
  table.sort(list)
  return table.concat(list, "|")
end


function svo.cpp.show_exits_caps()
  if not (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.exits) then return "" end

  local list = svo.keystolist(gmcp.Room.Info.exits)
  table.sort(list)
  return table.concat(list, "|"):upper()
end

registerAnonymousEventHandler("svo system loaded", function()
  svo.adddefinition("@exits", "svo.cpp.show_exits()")
  svo.adddefinition("@EXITS", "svo.cpp.show_exits_caps()")
end)