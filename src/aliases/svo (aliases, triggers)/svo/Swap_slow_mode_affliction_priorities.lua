-- vswapslow <aff> <aff> server swaps two priorities of the slowcuring set
if matches[4] and matches[4] ~= "" then
  svo.sk.serverprios_vswap(matches[2], matches[3], 'slowcuring')
  return
end

svo.prio_slowswap(matches[2], matches[3], true)
svo.sk.serverprios_remind()