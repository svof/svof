function svo.update_http_error(_, err, url)
  if not svo.update_response_is_ours(url) then return end
  svo.checkingupdates = false
  if svo.announceupdates then
    svo.echof("Couldn't reach GitHub to check for updates (%s).", tostring(err))
  end
  svo.announceupdates = nil
end
