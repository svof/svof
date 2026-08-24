disableTrigger("Check ih")
disableTrigger("Check ih prompt")

if #svo.set_target > 0 then
  selectCurrentLine() replace""
  svo.echof("Targetted %s", table.concat(svo.set_target, ", "))
  svo.showprompt()
  if not svo.conf.customprompt then wrapLine(getLineCount()) end
end

svo.set_target = nil