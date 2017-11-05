from strutils import parseInt
import strfmt

import ZonedDateTime

##
##    Advent begins 4 Sundays before December 25
##

proc displaySundaysInAdvent(start_year, stop_year: int) =
  for year in start_year..stop_year:
    let firstOfAdvent = toOrdinal(nth_kday(-4, 0, initDateTime(year, 12, 24)))
    var line =""
    for i in 0..3:
      if i > 0:
        line.add(" ")
      let d = fromOrdinal(firstOfAdvent + 7 * i)
      line.add(d.strftime("%Y-%m-%d "))
    echo line


proc displaySundaysInAdvent_1(start_year, stop_year: int) =
  # using the rule that the first sunday of advent
  # is between 11-27 and 12-03
  for year in start_year..stop_year:
    var start = toOrdinal(initDateTime(year, 11, 27))
    start = kday_on_or_after(0, start)
    var line = ""
    for i in 0..3:
      if i > 0:
        line.add(" ")
      let d = fromOrdinal(start + i * 7)
      line.add(d.strftime("%a %Y-%m-%d iso: $wiso "))
    echo line


when defined(js):
  import jsParams
else:
  import os


when isMainModule:
  var start_year: int
  var stop_year: int

  start_year = parseInt(paramStr(1))
  stop_year = parseInt(paramStr(2))

  displaySundaysInAdvent_1(start_year, stop_year)