import os
import strutils
from times import epochTime

import ZonedDateTime

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed",
                  "Thu", "Fri", "Sat"]

proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

proc getEtcLocalTime(ts: float64): DateTime =
  var data: TZFileContent
  data = readTZFile("/etc/localtime")
  var tzinfo = TZInfo(kind: tzOlson, olsonData: data)
  result = localFromTime(ts, tzinfo)

iterator localTimesPerZoneDir(lts: float64, zonedir: string): (string, DateTime) =
  var data: TZFileContent
  for filename in os.walkDirRec(zonedir):
    try:
      data = readTZFile(filename)
    except:
      continue
    if data.version == 2:
      var tzinfo = TZInfo(kind: tzOlson, olsonData: data)
      let lt = localFromTime(lts, tzinfo)
      let zoneName = filename.replace(zonedir,"")
      yield(zoneName, lt)

when isMainModule:
  if paramCount() < 1:
    echo "example invocation: ./listLocalTimesPerZoneDir /usr/share/zoneinfo"
    echo "to list the current systems local time (as configured in /etc/localtime)"
    echo "in every available Olson time zone definition below /usr/share/zoneinfo"
    echo "or: ./listLocalTimesPerZoneDir /usr/share/zoneinfo/Australia"
    echo "to list only the local time in Australia"
    quit(0)

  let zonedir = paramStr(1)
  let ts = epochTime()

  #
  # or to get the local time per zone dir for a
  # specific Date/Time
  #
  # let ts = initDateTime(2017, 10, 29, 3, 0, 0, 0)
  echo "epochTime() gives:     ", ts
  echo "in UTC this is:        ", fromUnixEpochSeconds(ts)
  let local = getEtcLocalTime(ts)
  echo "/etc/localtime is:     ", local
  echo "offset from UTC:       ", local.utcoffset
  echo "DST flag:              ", local.isDST
  echo "abbreviated Time Zone: ", local.zoneAbbrev
  echo "ISO Week Date:         ", toISOWeekDate(local)
  echo "Day of Year:           ", getYearDay(local)
  echo "Day of Week:           ", WEEKDAYS[getWeekDay(local)]

  echo ""
  echo "Date/Time in: ", zonedir
  printf("%-50s %-38s %s\n", "Zone Name", "Local Time in Zone", "Offset from here")
  echo "-".repeat(106)

  for zonename, lt in localTimesPerZoneDir(ts, zonedir):
    printf("%-50.50s %-38s %16s\n", zonename, $lt, $(lt - local))
