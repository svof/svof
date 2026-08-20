local function goto(whom)
  local p = whom:title()
  if not mmp.pdb[p] then mmp.echo("Sorry - don't know where "..p.." is.") return end

  local nums = mmp.getnums(mmp.pdb[p], true)
  mmp.gotoRoom(nums[1])
  mmp.echo(string.format("Going to %s in %s%s.", p, mmp.cleanAreaName(mmp.areatabler[getRoomArea(nums[1])] or '?'), (#nums ~= 1 and " (non-unique location though)" or "")))
end

if not matches[2] then
  if not target then
    mmp.echo("I don't know what your target is (set the 'target' variable)") return
  else
    goto(target)
  end
else
  goto(matches[2])
end