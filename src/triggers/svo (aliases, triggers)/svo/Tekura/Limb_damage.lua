if not svo.previous_paragraph_line():find("%f[%a]you%f[%A]") then return end

--Need to add the actual attack type here later - for now, "monk" will have to do
svo.valid.limb_hit(matches[3], "monk")

svo.startedfighting("monk", matches[2])