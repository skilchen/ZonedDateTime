import strutils

import ZonedDateTime

#proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

proc displayThanksGivingDate(start_year, stop_year: int) =
  ## Thanksgiving is celebrated on the second Monday of October in Canada
  ## and on the fourth Thursday of November in the United States
  ##
  for year in countUp(startYear, stop_year):
    let dc = nth_kday(2, 1, initDateTime(year, 10, 1))
    let dus = nth_kday(4, 4, initDateTime(year, 11, 1))
    # if dus.day + 7 <= 30:
    #   echo "5 Thursdays in ", dus.year, "-", dus.month
    echo dc.strftime("Canada: %a %Y-%m-%d, $wiso "), dus.strftime("US: %a %Y-%m-%d, $wiso")

when defined(js):
  import jsParams
else:
  import os

when isMainModule:
  if paramCount() < 2:
    echo ""
    echo "usage: displayThanksGiving from_year to_year"
  else:
    let start_year = parseInt(paramStr(1))
    var stop_year = parseInt(paramStr(2))

    displayThanksGivingDate(start_year, stop_year)
