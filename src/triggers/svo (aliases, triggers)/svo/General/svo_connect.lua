svo.connected()

if svo.conf.paused then svo.dont_unpause_login = true
else svo.app("on", true) end

svo.innews = true