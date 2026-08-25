function svo.isenemy(name)
  return (target and target:lower():starts(name:lower())) or ndb.isenemy(name)
end