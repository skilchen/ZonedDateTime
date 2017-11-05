import strutils

import ZonedDateTime

const FRIDAY = 5
const SUNDAY = 0

iterator getUnluckyFridays(start, stop: int64): DateTime =
  var a = start
  a = kday_on_or_after(FRIDAY, a + 1)
  while a <= stop:
    let d = fromOrdinal(a)
    if d.day == 13:
      yield d
    a = kday_on_or_after(FRIDAY, a + 1)

iterator getLuckySundays(start, stop: int64): DateTime =
  var a = start
  a = kday_on_or_after(SUNDAY, a + 1)
  while a <= stop:
    let d = fromOrdinal(a)
    if d.day == 1:
      yield d
    a = kday_on_or_after(SUNDAY, a + 1)

when defined(js):
  import jsParams
else:
  import os

when isMainModule:
  if paramCount() < 2:
    echo "unlucky Fridays means: Friday 13"
    echo "usage: displayUnluckyFridays from_year to_year"
  else:
    let start_year = parseInt(paramStr(1))
    let stop_year = parseInt(paramStr(2))
    let start = toOrdinal(initDateTime(start_year, 1, 1))
    let stop = toOrdinal(initDateTime(stop_year, 12, 31))
    for d in getUnluckyFridays(start, stop):
      echo format(d, "dddd dd'.' MMMM yyyy")
    echo ""
    for d in getLuckySundays(start, stop):
        echo format(d, "dddd dd'.' MMMM yyyy")
