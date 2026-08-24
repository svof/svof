if not commandCheck(StupeCheck) and not svo.affl.stupidity then
  wrapLine(0,0) echo("\n")
  svo.echof("Detected stupidity from stupidcheck")
  svo.valid.simplestupidity()
  svo.showprompt()
  svo.send_in_the_gnomes()
end