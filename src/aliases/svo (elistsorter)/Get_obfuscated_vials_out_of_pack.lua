if not svo.storedvials then svo.echof("We didn't store any obfuscated vials stored away.") svo.showprompt() return end

for vial in pairs(svo.storedvials) do
  send("get "..vial.." from "..svo.conf.obfcontainer, false)
end