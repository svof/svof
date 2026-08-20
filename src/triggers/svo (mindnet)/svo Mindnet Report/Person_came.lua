if not svo.conf.mindnet then return end

if not ndb or ndb.isenemy(matches[2]) then
  mindnet_entered = mindnet_entered or {}
  mindnet_entered[#mindnet_entered+1] = matches[2]


svo.prompttrigger("mindnet entered", function()
  -- use this if you want to show who entered
  -- send(string.format("pt %s ENTERED!", svo.concatand(mindnet_entered)))

  -- use this if you want to show who entered + number
  -- send(string.format("pt %s (%d) ENTERED!", svo.concatand(mindnet_entered), #mindnet_entered))

  -- use this if you want to show who entered + number + area
  svo.cc("%s (%d) ENTERED %s!", svo.concatand(mindnet_entered), #mindnet_entered, gmcp.Room.Info.area)

  mindnet_entered = nil
end)

end