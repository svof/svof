local affs = svo.affl

if not affs.crippledrightleg and not affs.mangledrightleg and not affs.mutilatedrightleg
  and not affs.crippledleftleg and not affs.mangledleftleg and not affs.mutilatedleftleg and not affs.unknowncrippledlimb and not affs.unknowncrippledleg and not affs.hamstring then
  svo.valid.simpleunknowncrippledleg()
end