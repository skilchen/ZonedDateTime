import ZonedDateTime

when defined(js):
  var zhr = initTZInfo("CET-1CEST,M3.5.0,M10.5.0/3", tzPosix)
else:
  var zhr = initTZInfo("CET-1CEST,M3.5.0,M10.5.0/3", tzPosix)
  #var zhr = initTZInfo("Europe/Zurich", tzOlson)
var utc = initTZInfo("UTC0", tzPosix)

var baseDate = initZonedDateTime(2017, 3, 26, 0, 59, 59, 999995, tzinfo = utc)
echo baseDate
baseDate = baseDate.astimezone(zhr)
echo baseDate
echo "---"

assert baseDate.isDST == false

for i in 1..10:
  let t = baseDate + i.microseconds
  echo t
  if t.microsecond == 0:
    assert t.hour == 3, "hour should jump to 3"
    assert t.isDST == true, "isDST flag must be set to true"
