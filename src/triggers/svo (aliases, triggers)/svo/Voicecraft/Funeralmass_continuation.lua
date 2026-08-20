if svo.fmass and svo.fmass.bard == matches[2] and svo.fmass.victim == "you" then
  svo.givewarning({
	initialmsg = string.format("%s is still continuing funeralmass on you!", matches[2]),
	prefixwarning = matches[2].." still fmass you",
	startin = 1,
	duration = 2
  })
else
  svo.givewarning({
	initialmsg = string.format("Someone is possibly continuing funeralmass on you!", matches[2]),
	prefixwarning = "Someone still fmass you",
	startin = 1,
	duration = 2
  })
end