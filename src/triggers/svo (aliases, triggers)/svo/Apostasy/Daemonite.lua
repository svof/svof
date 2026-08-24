if svo.me.passive_eqloss then killTimer(svo.me.passive_eqloss) end
svo.me.passive_eqloss = tempTimer(svo.conf.passive_eqloss, function() svo.me.passive_eqloss = nil end)