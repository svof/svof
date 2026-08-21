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

  -- ...but the tag is NOT the version where the download url is concerned.
  -- GitHub asset urls are tag-exact, and build.yml publishes "v65", so
  -- reconstructing the url from the stripped "65" is a guaranteed 404. Prefer
  -- the url the release itself gives us, and fall back to the raw tag rather
  -- than the stripped one.
  svo.pending_update_tag = tostring(release.tag_name)
  svo.pending_update_url = nil
  if type(release.assets) == "table" then
    for _, asset in ipairs(release.assets) do
      if type(asset) == "table" and asset.name == "svof.mpackage" and asset.browser_download_url then
        svo.pending_update_url = asset.browser_download_url
        break
      end
    end
  end
  svo.pending_update_url = svo.pending_update_url or svo.update_package_url(svo.pending_update_tag)

  if svo.announceupdates == "force" then
    svo.announceupdates = nil
    svo.install_update(latest, svo.pending_update_url)
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
