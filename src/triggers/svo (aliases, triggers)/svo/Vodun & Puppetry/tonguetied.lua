-- the condition finds your name anywhere in the line, so a puppet of a
-- longer name that holds yours counted too: the puppet's name must be yours
if multimatches[1][2] == svo.me.name then svo.valid.tonguetied_line('puppet') end