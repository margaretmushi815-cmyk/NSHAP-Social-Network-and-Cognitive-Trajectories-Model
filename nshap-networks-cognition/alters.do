egen alters = total(inrange(lineno,1,5))
 by(su_id); egen mt5 = total(lineno==5 &
      anymore=="yes":yesno)
 by(su_id); replace alters = 6 if mt5
 
 replace alters = .a if rosterintro == .a
