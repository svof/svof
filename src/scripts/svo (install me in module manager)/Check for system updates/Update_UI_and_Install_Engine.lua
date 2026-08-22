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

-- Is the file we just downloaded actually a Mudlet package? An .mpackage is a
-- zip, so it starts with "PK". This exists so a 404 page or an error page from
-- a proxy cannot get as far as uninstalling the working system.
function svo.update_looks_like_package(path)
  local f = io.open(path, "rb")
  if not f then return false, "the downloaded file isn't there" end
  local head = f:read(2)
  local size = f:seek("end")
  f:close()
  if head ~= "PK" then
    return false, string.format("it isn't a package (%d bytes, starting %q)",
                                size or 0, tostring(head))
  end
  return true
end

-- Downloads the package, then installs it from the local file. Announcing the
-- result is svo.update_download_done / svo.update_download_error's job.
--
-- This used to be uninstallPackage("svof") followed by installPackage(url) and
-- an immediate "installed, please restart". Both halves were wrong. The
-- download is asynchronous - installPackage(url) returns before it resolves -
-- so the success line printed on a 404 as readily as on a success, and the
-- uninstall had already removed the running system by then. A failed update
-- left the profile with no svof at all and a green message saying it had
-- worked.
--
-- The uninstall still has to happen - Mudlet refuses to install over an
-- existing package - but it belongs in svo.update_download_done, once the
-- replacement is on disk and has been checked, not out here in front of an
-- asynchronous download that may never arrive.
function svo.install_update(version, url)
  version = version or svo.pending_update_version
  url = url or svo.pending_update_url or svo.update_package_url(svo.pending_update_tag or version)

  if svo.update_target then
    svo.echof("Already downloading Svof %s - hold on.", tostring(svo.update_version))
    return
  end

  svo.echof("Installing Svof %s...", tostring(version))

  -- config is saved first: anything unsaved would be lost across the restart
  if svo.signals and svo.signals.saveconfig then
    pcall(function() svo.signals.saveconfig:emit() end)
  end

  svo.update_version = version
  svo.update_target = getMudletHomeDir() .. "/svof-update.mpackage"

  -- downloadFile returns nil, reason if it will not even start, and raises no
  -- event in that case. pcall's `ok` is true either way, so branching on it
  -- alone left svo.update_target set forever: every later attempt, including a
  -- hand-typed vupdate, answered "Already downloading" until Mudlet restarted.
  local ok, started, why = pcall(downloadFile, svo.update_target, url)
  if not ok then why = started end
  if not ok or not started then
    svo.update_target, svo.update_version = nil, nil
    svo.echof("Couldn't start the download for Svof %s: %s", tostring(version), tostring(why))
    return
  end

  if svo.updatelabel then
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Downloading Svof...<p>]])
  end
end
