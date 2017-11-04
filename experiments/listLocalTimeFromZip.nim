import os
import strutils
from times import epochTime

import zip/zipfiles

import ZonedDateTime

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed",
                  "Thu", "Fri", "Sat"]

proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

proc getEtcLocalTime(ts: float64): DateTime =
  var data: TZFileContent
  data = readTZFile("/etc/localtime")
  var tzinfo = TZInfo(kind: tzOlson, olsonData: data)
  result = localFromTime(ts, tzinfo)

iterator localTimesFromZip(lts: float64, zippath: string, zonedir: string): (string, DateTime) =
  var data: TZFileContent
  var zip: ZipArchive
  let fp = zip.open(zippath)
  for zonename in walkFiles(zip):
    if zonename.startswith(zonedir):
      try:
        var fp = getStream(zip, zonename)
        if not isNil(fp):
          data = readTZData(fp, zonename)
      except:
        continue
      if data.version == 2:
        var tzinfo = TZInfo(kind: tzOlson, olsonData: data)
        let lt = localFromTime(lts, tzinfo)
        #let zoneName = filename.replace(zonedir,"")
        yield(zonename, lt)
  zip.close()


when isMainModule:
  if paramCount() < 1:
    echo "example invocation: ./listLocalTimesPerZoneDir /usr/share/zoneinfo"
    echo "to list the current systems local time (as configured in /etc/localtime)"
    echo "in every available Olson time zone definition below /usr/share/zoneinfo"
    echo "or: ./listLocalTimesPerZoneDir /usr/share/zoneinfo/Australia"
    echo "to list only the local time in Australia"
    quit(0)

  const zipname = "zoneinfo.zip"
  let pardir = parentDir(getCurrentDir())
  var zippath = ""
  if fileExists(zipname):
    zippath = zipname
  elif fileExists(pardir / zipname):
    zippath = pardir / zipname
  else:
    echo "no zoneinfo.zip found"
    quit(1)

  var zone = paramStr(1)
  let ts = epochTime()

  if zone == "/":
    zone = ""
  
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
  echo "Date/Time in: ", zone
  printf("%-50s %-38s %s\n", "Zone Name", "Local Time in Zone", "Offset from here")
  echo "-".repeat(106)

  for zonename, lt in localTimesFromZip(ts, zippath, zone):
    printf("%-50.50s %-38s %16s\n", zonename, $lt, $(lt - local))
