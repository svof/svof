if svo.bals.leftarm then
  svo.valid.simplecrippledleftarm()
elseif svo.bals.rightarm then
  svo.valid.simplecrippledrightarm()
else
  svo.valid.simpleunknowncrippledarm()
end