import ZonedDateTime
import strutils
import lalign

var utc = initTZInfo("UTC0", tzPosix)

when defined(js):
  var zhr = initTZInfo("CET-1CEST,M3.5.0/1,M10.5.0", tzPosix)
  var tky = initTZInfo("JST-9", tzPosix)
  var nyc = initTZInfo("EST5EDT,M3.2.0,M11.1.0", tzPosix)
  var cas = initTZInfo("WET0WEST,M3.5.0,M10.5.0/3", tzPosix)
else:
  proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

  var zhr = initTZInfo("Europe/Zurich", tzOlson)
  var tky = initTZInfo("Asia/Tokyo", tzOlson)
  var nyc = initTZInfo("America/New_York", tzOlson)
  var cas = initTZInfo("Africa/Casablanca", tzOlson)

var baseDate = initZonedDateTime(2017,1,31,0,59,59, tzinfo=utc)
for i in 0..24:
  let d = baseDate + i.months
  let nyt = d.astimezone(nyc)
  let zht = d.astimezone(zhr)
  let tkt = d.astimezone(tky)
  let cat = d.astimezone(cas)

  when defined(js):
    echo(lalign($nyt, 30), " ", align($(nyt - zht), 8), " ",
         lalign($zht, 30), " ", align($(zht - tkt), 8), " ",
         lalign($tkt, 30), " ", align($(tkt - nyt), 8))
    # echo(lalign($cat, 30), " ", align($(cat - zht), 8))
  else:
    printf("%-30s %8s %-30s %8s %-30s %8s\n", $nyt, $(nyt - zht),
                                              $zht, $(zht - tkt),
                                              $tkt, $(tkt - nyt))
    # printf("%-30s %8s\n", $cat, $(cat - zht))
