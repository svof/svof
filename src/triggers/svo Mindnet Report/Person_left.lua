if not svo.conf.mindnet then return end

if not ndb or ndb.isenemy(matches[2]) then
  mindnet_left = mindnet_left or {}
  mindnet_left[#mindnet_left+1] = matches[2]

svo.prompttrigger("mindnet left", function()
  -- use this if you want to show who left
  -- send(string.format("pt %s LEFT!", svo.concatand(mindnet_left)))

  -- use this if you want to show who left + number
  -- send(string.format("pt %s (%d) LEFT!", svo.concatand(mindnet_left), #mindnet_left))

  -- use this if you want to show who left + number + area
  svo.cc("%s (%d) LEFT %s!", svo.concatand(mindnet_left), #mindnet_left, (gmcp.Room and gmcp.Room.Info.area or ''))

  mindnet_left = nil
end)

end