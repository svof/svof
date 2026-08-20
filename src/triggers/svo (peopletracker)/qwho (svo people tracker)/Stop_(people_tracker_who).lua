svo.deleteLineP()
disableTrigger("qwho (svo people tracker)")
if svo.qwhoopen then killTimer(svo.qwhoopen) end
svo.qwhoopen = nil
tempTimer(0, function() svo.echof("Done checking all of wholist!") svo.buildwhosummary() svo.showprompt() wrapLine("main", getLineCount()) end)
raiseEvent("mmapper updated pdb")