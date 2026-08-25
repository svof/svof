--[[ Iocuns prompt aff thingy from http://forums.achaea.com/index.php?showtopic=39543&view=findpost&p=1283964, taken with permission ]]
--[[ to use in a custom prompt, use the @paracelsus_affs_customtag tag ]]
--[[ this is now used by default in Svo ]]
local aff_abbrev = {
  ablaze              = "abl",
  addiction           = "add",
  aeon                = "ae",
  agoraphobia         = "agor",
  anorexia            = "ano",
  asleep              = "asl",
  asthma              = "ast",
  blackout            = "",
  bleeding            = "bld",
  blindaff            = "blind",
  blistered           = "blis",
  bound               = "bound",
  calcifiedskull      = "calh",
  calcifiedtorso      = "calt",
  charredburn         = "4burn",
  cholerichumour      = "choH",
  claustrophobia      = "clau",
  clumsiness          = "cl",
  confusion           = "con",
  corrupted           = "corr",
  crackedribs         = "cr",
  crescendo           = "cres",
  crippledleftarm     = "la1",
  crippledleftleg     = "ll1",
  crippledrightarm    = "ra1",
  crippledrightleg    = "rl1",
  crushedthroat       = 'cru',
  darkshade           = "dark",
  deadening           = "dea",
  deafaff             = "deaf",
  degenerate          = "deg",
  dehydrated          = "deh",
  dementia            = "dem",
  depression          = "dep",
  deteriorate         = "det",
  disloyalty          = "disl",
  disrupt             = "disr",
  dissonance          = "disso",
  dizziness           = "diz",
  earworm             = "ear",
  ensorcelled         = "ensor",
  epilepsy            = "epi",
  extremeburn         = "3burn",
  fear                = "fear",
  flamefisted         = "flame",
  flushings           = "flsh",
  frozen              = "frz",
  fulminated          = "ful",
  guilt               = 'gui',
  generosity          = "gen",
  haemophilia         = "haem",
  hallucinations      = "hall",
  hamstring           = "hms",
  hatred              = "htr",
  healthleech         = "hthl",
  heartseed           = "heart",
  hellsight           = "hell",
  horror              = "hor",
  hypersomnia         = "hypers",
  hypochondria        = "hypoch",
  icing               = "ice",
  illness             = "ill",
  impaled             = "impale",
  impatience          = "impat",
  justice             = "just",
  laceratedthroat     = "lac2",
  latched             = "latch",
  latency             = "laten",
  lethargy            = "let",
  loneliness          = "lon",
  lovers              = "lust",
  madness             = "mad",
  mangledleftarm      = "la2",
  mangledleftleg      = "ll2",
  mangledrightarm     = "ra2",
  mangledrightleg     = "rl2",
  masochism           = "maso",
  melancholichumour   = "melaH",
  meltingburn         = "5burn",
  mildconcussion      = "h1",
  mildtrauma          = "t1",
  mindravaged         = "ravg",
  mutilatedleftarm    = "la3",
  mutilatedleftleg    = "ll3",
  mutilatedrightarm   = "ra3",
  mutilatedrightleg   = "rl3",
  mycalium            = "myc",
  nausea              = "nau",
  ninkharsag          = "nkh",
  numbedleftarm       = "nbla",
  numbedrightarm      = "nbra",
  pacifism            = "pac",
  paradox             = "para",
  paralysis           = "par",
  paranoia            = "prn",
  parasite            = "prs",
  peace               = "pea",
  phlegmatichumour    = "phleH",
  phlogistication     = "phlog",
  pinshot             = "psh",
  pressure            = "pre",
  prone               = "pr",
  pyramides           = "pyr",
  pyre                = "pyre",
  rebbies             = "rebb",
  recklessness        = "reck",
  relapsing           = "scy",
  retardation         = "ret",
  retribution         = "reb",
  revealed            = "rev",
  roped               = "rop",
  sandfever           = "sndf",
  sanguinehumour      = "sanH",
  selarnia            = "sel",
  sensitivity         = "sen",
  seriousconcussion   = "h2",
  serioustrauma       = "t2",
  severeburn          = "2burn",
  shadowmadness       = "sham",
  shivering           = "shiv",
  shyness             = "shy",
  skullfractures      = "sf",
  slashedthroat       = "lac1",
  slickness           = "sli",
  spiritburn          = "sptb",
  stain               = "sta",
  stupidity           = "st",
  stuttering          = "stut",
  swellskin           = "swsk",
  tension             = "ten",
  tenderskin          = "tendr",
  timeflux            = "tfx",
  timeloop            = "tlp",
  torntendons         = "tt",
  transfixed          = "transf",
  unconsciousness     = "unconc",
  unknownany          = "?",
  unknowncrippledarm  = "uwna",
  unknowncrippledleg  = "uwnl",
  unknowncrippledlimb = "uwcrip",
  unknowncure         = "uc",
  unknownmental       = "?",
  unweavingbody       = "uwB",
  unweavingmind       = "uwM",
  unweavingspirit     = "uwS",
  vertigo             = "vert",
  vitrification       = "vitri",
  voided              = "void",
  voyria              = "voy",
  weakness            = "wea",
  webbed              = "web",
  wristfractures      = "wf",
}

-- recoded, it's quicker by a third
function paracelsus_affs_customtag2()
  if next(svo.affl) then
    local s, type = {}, type
    for k,v in pairs(svo.affl) do
        if (k == "unknownany" or k == "unknownmental") and (type(v) == 'table') then
          s[#s+1] = ("?"):rep(v.count)
        elseif k == "bleeding" and type(v) == 'table' then
          if v.count >= svo.conf.bleedamount then
            s[#s+1] = string.format("bld(%d)", v.count)
          end
       elseif k == "lovers" and type(v) == 'table' then
          s[#s+1] = string.format("lust(%s)", svo.oneconcat(svo.affl.lovers.names))
        elseif type(v) == 'table' and v.count then
          s[#s+1] = (aff_abbrev[k] or k)..'('..v.count..')'
        else
          s[#s+1] = (aff_abbrev[k] or k)
        end
    end
    return #s > 0 and ("<IndianRed>["..table.concat(s, " ").."]") or "" -- don't display just [] b/c of bleeding
  else
    return ""
  end
end

registerAnonymousEventHandler("svo system loaded", function()
  svo.adddefinition("@paracelsus_affs_customtag", "paracelsus_affs_customtag2()")
  svo.adddefinition("@affs", "paracelsus_affs_customtag2()")
  
  svo.adddefinition("@target", "target")
end)