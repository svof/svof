local l = (next(svo.me.watchfor) and svo.oneconcat(svo.me.watchfor) or "(none - use vconfig watchfor <person> to add)")
svo.echof("People on the watchfor list: %s", l)
svo.showprompt()