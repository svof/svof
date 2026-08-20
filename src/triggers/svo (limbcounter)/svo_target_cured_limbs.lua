local part = matches[3]
local person = matches[2]
if not svo.lc_limbreset then
	svo.lc_appliedreset(part, person)
end