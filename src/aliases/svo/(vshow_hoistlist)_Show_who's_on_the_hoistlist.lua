local l = (next(svo.me.hoistlist) and svo.oneconcat(svo.me.hoistlist) or "(none)")
if svo.conf.autowrithe == "white" then
  svo.echof("People we're not writhing against: %s", l)
elseif svo.conf.autowrithe == "black" then
  svo.echof("The only people we're writhing against: %s", l)
else
  svo.echof("People on the hoistlist: %s", l)
end