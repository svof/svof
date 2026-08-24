if svo.defc.dragonform then return end

local requester, sought = matches[2], matches[3]

if not svo.me.locatelist[requester] then svo.ignore_illusion("This person isn't on our locatelist - if you want to allow them, do vconfig locatelist "..requester) return end

svo.locating = {person = matches[2], name = matches[3]}
svo.doaddfree("angel seek "..svo.locating.name)