enableTrigger("Check ih prompt")

local ignore = {"totem", "sigil", "blanket", "shrine", "steed", "hippogriff", "pegasus", "beehive", "lever", "gate", "box"}

if table.contains(ignore, matches[2]) then return end
local id = tonumber(matches[3])
if id == svo.bees or id == svo.efreeti or id == svo.weird or id == svo.golem then return end

if target1 == 0 then
  target1 = id
  svo.set_target[#svo.set_target+1] = matches[2]
elseif target2 == 0 then
  target2 = id
  svo.set_target[#svo.set_target+1] = matches[2]
elseif target3 == 0 then
  target3 = id
  svo.set_target[#svo.set_target+1] = matches[2]
end