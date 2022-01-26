Svof Tattoo Inker
=================
This script simplifies the process of inking tattoos! Does your tattoos, and tattoos for other people - and allows queueing up of several tattoo orders at once, so you can do a newbies set all with one command, for example. It outrifts inks, the body for a free location, and inks the tattoo. Also touches tattoos requiring activation, or if its for someone else, tells them which tattoos to touch at the end.

If inking gets interrupted, it'll show a warning, wait a bit, and resume inking again.


Configs
^^^^^^^^
**vconfig telltouch** 
  tell people to touch the tattoos that need touching after inking.

**vconfig autorink**
  toggle whether or not you auto reink a tattoo after being interrupted
  
Aliases
^^^^^^^^
**ink <tattoos> on <person>**
  Inks the given tattoos on yourself or another person on any open bodypart - outrs the inks, pauses the system, and automatically touches at the end. You can queue several tattoos to be inked at once by separating them with a comma - **ink boar** will ink one tattoo on you, while **ink boar, moss, moon** will ink several!

**ink <tattoos> on <bodypart>**
  Inks the given tattoos on yourself but uses a specific bodypart. 

**ink <tattoos> on <bodypart> of <person>**
 Inks the given tattoos on a specific bodypart of somebody else, and then tells whem which to touch at the end that need activation (if *telltouch* option is on)

API
^^^^
**svo.ti_ink(tattoos, place, person)**
  Same as the alias, starts inking tattoos. If no person is given, will check the place variable for person or bodypart.
