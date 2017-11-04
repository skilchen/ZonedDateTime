import ZonedDateTime

when not defined(js):
  import os

proc list_per_interval(from_start, to_end: ZonedDateTime, interval:TimeInterval) =
  var curr = from_start
  var i = 0
  while curr <= to_end:
    echo $curr
    inc(i)
    curr = from_start + i * interval

proc main() =
  let fmt = "yyyy-MM-dd HH:mm:ss"
  var interval = seconds(1)

  when defined(testing):
    var from_start = parse("2017-09-24 02:44:50", fmt)
    var to_end = parse("2017-09-24 03:45:10", fmt)
    var tz = "<+1245>-12:45<+1345>,M9.5.0/2:45,M4.1.0/3:45"
    interval = 1.seconds
  else:
    var from_start = parse(paramStr(1), fmt)
    var to_end = parse(paramStr(2), fmt)
    var tz = paramStr(3)
    interval = 1.seconds

  var tzinfo = initTZInfo(tz, tzPosix)
  #echo repr(tzinfo)
  #echo ""

  var zf = initZonedDatetime(from_start, tzinfo)
  zf = zf.settimezone(tzinfo)
  zf.datetime.isDST = false
  zf = zf + 0.seconds
  var zt = initZonedDateTime(to_end, tzinfo)
  zt = zt.settimezone(tzinfo)

  echo zf, " ", zt
  # echo repr(find_transition(addr(tzinfo.posixData), toUTCTime(zf.datetime)))

  list_per_interval(zf, zt, interval)

when isMainModule:
  main()

#var nzl = initTZInfo("<+1245>-12:45<+1345>,M9.5.0/2:45,M4.1.0/3:45", tzPosix)