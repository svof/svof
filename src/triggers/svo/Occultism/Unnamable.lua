svo.startedfighting("occultist", matches[2])

if matches[2] == "3" then
  svo.valid.simplestupidity()
	svo.valid.simpleconfusion()
	svo.valid.simpledementia()
elseif matches[2] == "2" then
  svo.valid.simpleunknownany(2)
else
  svo.valid.simpleunknownany()
end