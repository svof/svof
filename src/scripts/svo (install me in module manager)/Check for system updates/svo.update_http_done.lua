-- sysGetHttpDone fires for every request the profile makes, so check the url
function svo.update_http_done(_, url, body)
  if url ~= svo.update_api_url() then return end
  svo.checkingupdates = false

  local ok, release = pcall(yajl.to_value, body)
  if not ok or type(release) ~= "table" or not release.tag_name then
    if svo.announceupdates then svo.echof("Couldn't read the update information - try again later.") end
    svo.announceupdates = nil
    return
  end

  -- release tags are often prefixed, and the version itself is what matters
  local latest = tostring(release.tag_name):gsub("^[vV]", "")

  if svo.announceupdates == "force" then
    svo.announceupdates = nil
    svo.install_update(latest)
    return
  end

  if not svo.version_newer(latest, svo.version) then
    if svo.announceupdates == "checking" then
      svo.echof("You're all good! Latest version is %s and you're on it.", tostring(svo.version))
    end
    svo.announceupdates = nil
    return
  end

  if svo.announceupdates == "checking" then
    svo.echof("A new Svof is available! You're on %s, latest is %s.", tostring(svo.version), latest)
  end
  svo.announceupdates = nil
  svo.showupdatereminder(latest)
end
