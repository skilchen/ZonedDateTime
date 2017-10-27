import os

import ZonedDateTime

proc main() =
  if paramCount() < 2:
    echo """Example invocation: ./showTimeInZone "2017-10-29 02:59:59+02:00\" /usr/share/zoneinfo/Europe/Berlin"""
    echo "and then:"
    echo "./showTimeInZone \"2017-10-29 03:00:00+02:00\" /usr/share/zoneinfo/Europe/Berlin"
    echo "to see the effect of a DST transition"
    quit(0)

  let dt = parse(paramStr(1), "yyyy-MM-dd hh:mm:sszzz")
  let utct = toTime(dt) + float(dt.utcOffset - int(dt.isDST) * 3600)
  var localzone = readtzfile("/etc/localtime")
  var tzinfo = TZInfo(kind: tzOlson, olsonData: localzone)
  let dt1 = localFromTime(utct, tzinfo)

  let tr = find_transition(localzone.transitionData[1], dt)
  #echo repr(tr)
  echo "last transition:   ", fromTime(float(tr.time))

  var tz = readtzfile(paramStr(2))
  tzinfo = TZInfo(kind: tzOlson, olsonData: tz)
  let lt = localFromTime(utct, tzinfo)

  echo "parsed:            ", dt
  echo "zoned:             ", dt1
  echo "converted :        ", lt
  let td = lt - dt1
  var tdstr = $td
  if td.days < 0:
    tdstr = "-" & $initTimeDelta(seconds = -1 * td.totalSeconds())
  echo "delta:             ", tdstr, " in seconds: ", td.totalSeconds()

  echo ""
  echo "and now using the Posix TZ embedded in the zoneinfo file: ", tz.posixTZ
  var posixTZ: TZRuleData
  if parsetz(tz.posixTZ, posixTZ):
    tzinfo = TZInfo(kind: tzPosix, posixData: posixTZ)
    let ltp = localFromTime(utct, tzinfo)
    echo "using posix Rule: ", ltp
    let td = ltp - dt1
    tdstr = $td
    if td.days < 0:
      tdstr = "-" & $initTimeDelta(seconds = -1 * td.totalSeconds())
    echo "delta:            ", tdstr, " in seconds: ", td.totalSeconds()



main()
