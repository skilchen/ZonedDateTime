import ZonedDateTime

proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

var utc = initTZInfo("UTC0", tzPosix)
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

  printf("%-30s %8s %-30s %8s %s %8s\n", $nyt, $(nyt - d),
                                         $zht, $(zht - d),
                                         $tkt, $(tkt - d))
#  printf("%-30s %8s\n", $cat, $(cat - d))
