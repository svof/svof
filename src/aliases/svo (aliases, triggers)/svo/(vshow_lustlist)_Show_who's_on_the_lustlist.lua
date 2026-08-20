local l = (next(svo.me.lustlist) and svo.oneconcat(svo.me.lustlist) or "(none)")
if svo.conf.autoreject == "white" then
  svo.echof("People we're not rejecting: %s", l)
elseif svo.conf.autoreject == "black" then
  svo.echof("The only people we're rejecting: %s", l)
else
  svo.echof("People on the lustlist: %s", l)
end