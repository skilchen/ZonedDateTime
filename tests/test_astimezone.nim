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
  let nyt = d.astimezone(nyc)
  let zht = d.astimezone(zhr)
  let tkt = d.astimezone(tky)
  let cat = d.astimezone(cas)

#  printf("%-30s %8s %-30s %8s %s %8s\n", $nyt, $(nyt - zht),
#                                         $zht, $(zht - tkt),
#                                         $tkt, $(tkt - nyt))
  printf("%-30s %8s\n", $cat, $(cat - zht))
