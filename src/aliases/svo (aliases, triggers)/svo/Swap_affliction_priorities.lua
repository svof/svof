-- vswap <aff> <aff> server swaps two serverside priorities
if matches[4] == "server" and (not matches[5] or matches[5] == "") then
  svo.sk.serverprios_vswap(matches[2], matches[3], 'normal')
  return
end

svo.prio_swap(matches[2], matches[3], matches[4], matches[5], true)
svo.sk.serverprios_remind()