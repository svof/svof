-- sysGetHttpDone fires for every request the profile makes, so check that this
-- response is the one our check asked for - see svo.update_response_is_ours,
-- which also covers the redirect GitHub serves for a renamed repository.
function svo.update_http_done(_, url, body)
  if not svo.update_response_is_ours(url) then return end
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
  local assets = 0
  if type(release.assets) == "table" then
    for _, asset in ipairs(release.assets) do
      if type(asset) == "table" and asset.name then
        assets = assets + 1
        if asset.name == "svof.mpackage" and asset.browser_download_url then
          svo.pending_update_url = asset.browser_download_url
        end
      end
    end
  end

  -- A release that carries assets but no svof.mpackage cannot be installed
  -- from, and reconstructing a download url for one produces a 404 dressed up
  -- as an offer to update. Say what is actually there instead. This is not
  -- hypothetical: the newest release of svof/svof today is tag 34, whose 20
  -- assets are all per-class zips from the module era.
  local installable = svo.pending_update_url ~= nil or assets == 0
  svo.pending_update_url = svo.pending_update_url or svo.update_package_url(svo.pending_update_tag)

  local function no_package()
    if svo.announceupdates then
      svo.echof("Release %s doesn't include a svof.mpackage, so there's nothing to install from it.",
                svo.pending_update_tag)
    end
    svo.announceupdates = nil
  end

  if svo.announceupdates == "force" then
    if not installable then return no_package() end
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

  if not installable then return no_package() end

  if svo.announceupdates == "checking" then
    svo.echof("A new Svof is available! You're on %s, latest is %s.", tostring(svo.version), latest)
  end
  svo.announceupdates = nil
  svo.showupdatereminder(latest)
end
