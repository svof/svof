if svo.conf.aillusion and svo.conf.ignoresinglestabs and not string.find(svo.previous_paragraph_line(), "^The attack rebounds back onto") then
  svo.ignore_illusion("Ignored the single-aff doublestab (vconfig ignoresinglestabs is on)", true)
end