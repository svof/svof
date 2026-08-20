function svo.autopause_on_def(event, def)
  if (def == "blackwind" or def == "astralform") and event == "svo got def" then
    if svo.conf.paused then svo.dont_unpause_for_bw = true
    else svo.app("on") end
  elseif (def == "blackwind" or def == "astralform") and event == "svo lost def" then
    if not svo.dont_unpause_for_bw then svo.app("off") end
    svo.dont_unpause_for_bw = nil
  end
end