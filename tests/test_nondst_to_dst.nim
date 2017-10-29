import ZonedDateTime

var zhr = initTZInfo("Europe/Zurich", tzOlson)
var utc = initTZInfo("UTC0", tzPosix)

var baseDate = initZonedDateTime(2017, 3, 26, 0, 59, 59, 999995, tzinfo = utc)
echo baseDate
baseDate = baseDate.astimezone(zhr)
echo baseDate
echo "---"

for i in 1..10:
  echo baseDate + i.microseconds
