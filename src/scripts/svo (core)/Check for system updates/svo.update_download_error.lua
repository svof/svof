-- The failure half of svo.update_download_done. Nothing was uninstalled before
-- the download started, so there is nothing to restore here - the running
-- system is still the one that was running before the attempt.
--
-- Argument order for sysDownloadError has varied between Mudlet versions, so
-- match the target against every argument rather than assuming a position.
function svo.update_download_error(_, ...)
  if not svo.update_target then return end

  local mine, reason = false, nil
  for i = 1, select("#", ...) do
    local a = select(i, ...)
    if a == svo.update_target then mine = true
    elseif type(a) == "string" and not reason then reason = a end
  end
  if not mine then return end

  local version = svo.update_version
  svo.update_target, svo.update_version = nil, nil

  svo.echof("Couldn't download Svof %s: %s", tostring(version), tostring(reason or "unknown error"))
  svo.echof("Nothing was changed - you're still on %s.", tostring(svo.version))

  if svo.updatelabel then svo.updatelabel:hide() end
  if svo.doupdatelabel then svo.doupdatelabel:hide() end
  if svo.dontupdatelabel then svo.dontupdatelabel:hide() end
end
