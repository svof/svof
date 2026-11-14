-- vset <aff> [slowcuring] <number> server sets a serverside priority
if matches[5] and matches[5] ~= "" then
  svo.sk.serverprios_vset(matches[2], matches[3], matches[4])
  return
end

if not matches[3] or matches[3] == "" then
  svo.echof("Which balance? Use vset <action> <balance> <number>, or put server at the end for a serverside priority.")
  return
end

svo.prio.insert(matches[2], matches[3], matches[4], true)
svo.sk.serverprios_remind()