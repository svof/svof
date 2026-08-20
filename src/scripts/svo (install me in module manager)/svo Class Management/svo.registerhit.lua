function svo.registerhit(_, class, name)
  if not svo.classes[class] or not svo.conf.autoclasses then return end

  if not svo.enabledclasses[class] then
    svo.maybefighting[class] = (svo.maybefighting[class] or 0) + 1

    tempTimer(svo.conf.classattackswithin, function()
      if svo.maybefighting[class] then
        svo.maybefighting[class] = svo.maybefighting[class] - 1
        if svo.maybefighting[class] <= 0 then
          svo.maybefighting[class] = nil
        end
      end
    end)
  end

  -- enable if we got attacked enough
  if svo.maybefighting[class] and svo.maybefighting[class] >= svo.conf.classattacksamount and not svo.enabledclasses[class] then
    svo.enableclass(class)
    svo.prompttrigger("enabled "..class, function() svo.echof("Seems that we're fighting with %s - enabled class tricks.", string.title(class)) end)
  end

  -- start/renew timer
  if svo.classes[class].fighting then killTimer(svo.classes[class].fighting) end
  svo.classes[class].fighting = tempTimer(60*svo.conf.enableclassesfor, function()
    svo.classes[class].fighting = nil
    if not svo.enabledclasses[class] then return end

    svo.disableclass(class)
    if svo.stats.currenthealth ~= 0 then echo'\n' svo.echof("Don't think we're fighting with class %s anymore, disabled tricks.", string.title(class)) end
    svo.showprompt()
  end)
end