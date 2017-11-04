import ZonedDateTime

when defined(js):
  var zhr = initTZInfo("CET-1CEST,M3.5.0,M10.5.0/3", tzPosix)
else:
  #var zhr = initTZInfo("Europe/Zurich", tzOlson)
  var zhr = initTZInfo("CET-1CEST,M3.5.0,M10.5.0/3", tzPosix)
var utc = initTZInfo("UTC0", tzPosix)

var baseDate = initZonedDateTime(year = 2017, month = 10, day = 29,
                                 hour = 0, minute = 59, second = 59,
                                 microsecond = 999995, tzinfo = utc)
#var baseDate = initDateTime(2017, 10, 29, 0, 59, 59, 999995)
echo baseDate
baseDate = baseDate.astimezone(zhr)
echo baseDate
echo "---"

doAssert(baseDate.isDST == true)

for i in 1..10:
  let  t = baseDate + i.microseconds
  echo t
  if t.microsecond == 0:
    doAssert(t.hour == 2)
    doAssert(t.isDST == false)
