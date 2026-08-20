function svo.showupdatereminder(newversion)
  -- Remember which version the reminder is offering. The click handler used to
  -- read a bare `newversion` global that nothing ever assigned - only this
  -- function's parameter has that name - so it passed nil to the installer.
  svo.pending_update_version = newversion
  svo.updatelabel = svo.updatelabel or Geyser.Label:new({
    name = "svo.updatelabel",
    x = "-340px", y = "-115px",
    width = "320px", height = "110px",
  })

  svo.doupdatelabel = svo.doupdatelabel or Geyser.Label:new({
    name = "svo.doupdatelabel",
    x = "25%", y = "-30px",
    width = "20%", height = "20px",
  }, svo.updatelabel)

  svo.dontupdatelabel = svo.dontupdatelabel or Geyser.Label:new({
    name = "svo.dontupdatelabel",
    x = "55%", y = "-30px",
    width = "20%", height = "20px",
  }, svo.updatelabel)

  -- grey to black shade, top to bottom
  svo.updatelabel:setStyleSheet([[
      margin: 0px;
      padding: 2px;

      /* Vertical gradient */
      background: qlineargradient(
          x1: 0, y1: 0, x2: 0, y2: 1,
          stop: 0 #3c3c3c, stop: 1 #232323
      );

      border: none;
      border-radius: 4px;

      color: #ffffff;

    qproperty-alignment: 'AlignTop | AlignHCenter';
    qproperty-wordWrap: true;
    font-family: 'Ubuntu','Calibri',serif;
  ]])

  svo.doupdatelabel:setStyleSheet([[
    border-radius: 4px;
    border-style: double;
    border-width: 2px;
    border-color: green;
    font-family: monospace;
  ]])

  svo.dontupdatelabel:setStyleSheet([[
    border-radius: 4px;
    border-style: double;
    border-width: 2px;
    border-color: grey;
    font-family: monospace;
  ]])

  svo.updatelabel:echo(string.format([[<p align="center" style="font-size:10pt; color:white">Hey, a new Svof (%s) is available for download!<br><br>Install and restart now, or install later?<p>]], newversion))

  svo.doupdatelabel:echo([[<p align="center" style="font-size:8pt; color:white">Install</p]])

  svo.dontupdatelabel:echo([[<p align="center" style="font-size:8pt; color:white">Later</p]])

  svo.updatelabel:show()
  svo.doupdatelabel:show()
  svo.dontupdatelabel:show()

  svo.doupdatelabel:setClickCallback("svo_doupdate_click")
  svo.dontupdatelabel:setClickCallback("svo_dontupdate_click")
end

function svo_dontupdate_click()
  svo.updatelabel:hide()
  svo.doupdatelabel:hide()
  svo.dontupdatelabel:hide()
end

function svo_doupdate_click()
  svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Updating Svo...<p>]])
  svo.doupdatelabel:hide()
  svo.dontupdatelabel:hide()
  svo.install_update(svo.pending_update_version)
end

-- Mudlet installs a package straight from a URL, so updating is uninstall
-- followed by install. The old engine downloaded 24 module xmls, deleted the
-- installed ones, renamed the downloads into place and reloaded each module;
-- none of that applies to a package.
function svo.install_update(version)
  local url = svo.update_package_url(version)

  svo.echof("Installing Svof %s...", tostring(version))

  -- config is saved first: uninstalling drops the running system, and anything
  -- unsaved would go with it
  if svo.signals and svo.signals.saveconfig then
    pcall(function() svo.signals.saveconfig:emit() end)
  end

  -- the install has to happen after this handler returns, since uninstalling
  -- removes the very script that is running
  tempTimer(0, function()
    pcall(uninstallPackage, "svof")
    -- installPackage's return value is unreliable across Mudlet versions
    -- (4.15-4.19 report nothing on success), so it is not branched on
    installPackage(url)
    cecho("\n<green_yellow>Svof: installed " .. tostring(version) ..
          ". Please restart Mudlet to finish.\n")
  end)

  if svo.updatelabel then
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Svof updated! Please restart Mudlet.<p>]])
    tempTimer(10, function() if svo.updatelabel then svo.updatelabel:hide() end end)
  end
end
