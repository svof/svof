-- sysDownloadDone fires for every download the profile makes, so check that
-- this one is ours before acting - the same guard svo.update_http_done uses.
--
-- This exists because installing is asynchronous. The engine used to call
-- installPackage(url) and echo "installed, please restart" on the next line,
-- which printed whether the download succeeded or 404'd. Announcing from here
-- means the message reports what actually happened.
function svo.update_download_done(_, path)
  if not svo.update_target or path ~= svo.update_target then return end

  local target, version = svo.update_target, svo.update_version
  svo.update_target, svo.update_version = nil, nil

  local ok, err = pcall(installPackage, target)
  if not ok then
    svo.echof("Downloaded Svof %s but couldn't install it: %s", tostring(version), tostring(err))
    if svo.updatelabel then svo.updatelabel:hide() end
    return
  end

  cecho("\n<green_yellow>Svof: installed " .. tostring(version) ..
        ". Please restart Mudlet to finish.\n")

  if svo.updatelabel then
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Svof updated! Please restart Mudlet.<p>]])
    tempTimer(10, function() if svo.updatelabel then svo.updatelabel:hide() end end)
  end
end
