local bigboxaffs = {"serioustrauma", "mildtrauma", "mildconcussion", "seriousconcussion", "mutilatedleftarm", "mutilatedleftleg", "mutilatedrightarm", "mutilatedrightleg", "mangledleftarm", "mangledleftleg", "mangledrightarm", "mangledrightleg"}
local bigboxaffs_t = {}; for i = 1, #bigboxaffs do bigboxaffs_t[bigboxaffs[i]] = true end

function svo_onimportant_aff(_, which)
  if bigboxaffs_t[which] then
    svo.boxDisplay("afflicted w/ "..which, "black:DarkOrange")
  end
end