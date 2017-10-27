import ZonedDateTime
from times import epochTime
from math import `mod`
from strutils import replace, repeat

when isMainModule:
  import os
  if paramCount() < 1:
    echo "example invocation: ./myzdump Europe/Berlin Asia/Tokyo America/Los_Angeles"
    echo "to see the current time in Berlin, Tokyo and Los Angeles"
    echo "it assumes that the Olson time zone files can be found"
    echo "in /usr/share/zoneinfo. Adapt zonedir if your sytem has"
    echo "these files in another directory."


  let zonedir = "/usr/share/zoneinfo/"
  let ts = epochTime()
  let colWidth = 50
  var zones: seq[string] = @[]
  var ltimes: seq[DateTime] = @[]
  for i in 1..paramCount():
    var data: TZFileContent
    let fn = zonedir / paramStr(i)
    data = readTZFile(fn)
    var tzinfo = TZInfo(kind: tzOlson, olsonData: data)
    let lt = localFromTime(ts, tzinfo)
    ltimes.add(lt)
    zones.add($paramStr(i))
  for i in 0..high(zones):
    echo zones[i], " ".repeat(colWidth - len(zones[i])), " ", ltimes[i]