svo.off_preaction = matches[2]
svo.off_action = matches[3]
if svo.off_preaction ~= "get" then
  if svo.off_preaction ~= "give" and 
     svo.off_preaction ~= "put" and 
     svo.off_preaction ~= "drop" then
       enableTrigger("Shrine full/gone")
  end
  sendGMCP("Char.Items.Inv")
else
  sendGMCP("Char.Items.Room")
end
send(" ")