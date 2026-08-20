svo.givevials = {person = matches[2]}

if svo.defkeepup[svo.defs.mode].selfishness then
  svo.defs.keepup("selfishness", false)
  svo.givevials.selfish = true
end

svo.doadd("give 50 vial to "..svo.givevials.person)