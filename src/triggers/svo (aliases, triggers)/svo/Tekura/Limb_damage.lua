if not getLines(getLineNumber()-1, getLineNumber())[1]:find("%f[%a]you%f[%A]") then return end

--Need to add the actual attack type here later - for now, "monk" will have to do
svo.valid.limb_hit(matches[3], "monk")

svo.startedfighting("monk", matches[2])