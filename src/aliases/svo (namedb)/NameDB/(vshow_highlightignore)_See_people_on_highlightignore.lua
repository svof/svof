local l = (next(svo.me.highlightignore) and svo.oneconcat(svo.me.highlightignore) or "(none - use vconfig highlightignore <person> to add)")
svo.echof("People on the highlightignore (those, who shouldn't be highlighted by NameDB) list: %s", l)
svo.showprompt()