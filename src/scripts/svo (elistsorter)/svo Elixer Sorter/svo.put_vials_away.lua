function svo.put_vials_away()
  if not svo.storedvials then return end
  
  for vial in pairs(svo.storedvials) do
    send("get "..vial.." from "..svo.conf.obfcontainer, false)
  end
  
  svo.storedvials = {}
end