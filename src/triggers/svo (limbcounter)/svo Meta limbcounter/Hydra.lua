local hit = svo.lc_break_at / 4
hit = string.format("%2.1f", hit)
hit = tonumber(hit)
svo.lc_hit(multimatches[2][2], multimatches[2][3], hit)