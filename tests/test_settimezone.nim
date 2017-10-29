import ZonedDateTime

import strutils
import lalign

var utc = initTZInfo("UTC0", tzPosix)

proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

when defined(js):
  var zhr = initTZInfo("CET-1CEST,M3.5.0/1,M10.5.0", tzPosix)
  var tky = initTZInfo("JST-9", tzPosix)
  var nyc = initTZInfo("EST5EDT,M3.2.0,M11.1.0", tzPosix)
  var cas = initTZInfo("WET0WEST,M3.5.0,M10.5.0/3", tzPosix)
else:
  var zhr = initTZInfo("Europe/Zurich", tzOlson)
  var tky = initTZInfo("Asia/Tokyo", tzOlson)
  var nyc = initTZInfo("America/New_York", tzOlson)
  var cas = initTZInfo("Africa/Casablanca", tzOlson)

var baseDate = initZonedDateTime(2017,1,31,0,59,59, tzinfo=utc)
for i in 0..24:
  let d = baseDate + i.months
  let nyt = d.settimezone(nyc)
  let zht = d.settimezone(zhr)
  let tkt = d.settimezone(tky)
  let cat = d.settimezone(cas)

  when defined(js):
    echo(lalign($nyt, 30), " ", align($(nyt - d), 8), " ",
         lalign($zht, 30), " ", align($(zht - d), 8), " ",
         lalign($tkt, 32), " ", align($(tkt - d), 8))
    # echo(lalign($cat, 30), " ", align($(cat - d), 8))
  else:
    printf("%-30s %8s %-30s %8s %s %8s\n", $nyt, $(nyt - d),
                                           $zht, $(zht - d),
                                           $tkt, $(tkt - d))
    # printf("%-30s %8s\n", $cat, $(cat - d))
