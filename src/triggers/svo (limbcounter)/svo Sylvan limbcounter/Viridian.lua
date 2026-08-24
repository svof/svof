-- "You command the razor-edged thorny vines around you to lash out and rend the flesh of an unformed thing of chaos." will capture "flesh" instead of the limb, so check for that
local limbs = {"head", "torso", "right arm", "left arm", "right leg", "left leg"}
if table.contains(limbs, multimatches[2][2]) then
  local hit = svo.lc_break_at / 4
	hit = string.format("%2.1f", hit)
	hit = tonumber(hit)
	svo.lc_hit(multimatches[2][3], multimatches[2][2], hit)
end