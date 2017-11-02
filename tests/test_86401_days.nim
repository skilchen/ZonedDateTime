import ZonedDateTime

const NTP_EPOCH = -2208988800

var LeapSecondData = [
  [2272060800, 10], # 1 Jan 192
  [2287785600, 11], # 1 Jul 1972
  [2303683200, 12], # 1 Jan 1973
  [2335219200, 13], # 1 Jan 1974
  [2366755200, 14], # 1 Jan 1975
  [2398291200, 15], # 1 Jan 1976
  [2429913600, 16], # 1 Jan 1977
  [2461449600, 17], # 1 Jan 1978
  [2492985600, 18], # 1 Jan 1979
  [2524521600, 19], # 1 Jan 1980
  [2571782400, 20], # 1 Jul 1981
  [2603318400, 21], # 1 Jul 1982
  [2634854400, 22], # 1 Jul 1983
  [2698012800, 23], # 1 Jul 1985
  [2776982400, 24], # 1 Jan 1988
  [2840140800, 25], # 1 Jan 1990
  [2871676800, 26], # 1 Jan 1991
  [2918937600, 27], # 1 Jul 1992
  [2950473600, 28], # 1 Jul 1993
  [2982009600, 29], # 1 Jul 1994
  [3029443200, 30], # 1 Jan 1996
  [3076704000, 31], # 1 Jul 1997
  [3124137600, 32], # 1 Jan 1999
  [3345062400, 33], # 1 Jan 2006
  [3439756800, 34], # 1 Jan 2009
  [3550089600, 35], # 1 Jul 2012
  [3644697600, 36], # 1 Jul 2015
  [3692217600, 37], # 1 Jan 2017
]

proc test_86401_days() =
  var tz = initTZInfo("/usr/share/zoneinfo/right/UTC", tzOlson)

  for lsinfo in LeapSecondData[2..^1]:
    let ttime = lsinfo[0]
    let corr = lsinfo[1] - 10
    var ep_ttime = ttime + NTP_EPOCH
    var before = initZonedDateTime(localFromTime((ep_ttime + corr - 3600 * 3 - 1).float64, tz), tz)
    let b = before
    var after = initZonedDateTime(b.year, b.month, b.day + 1, b.hour, b.minute, b.second, b.microsecond, tzinfo=tz)
    var td = after - before
    echo before, " ", after, " ", td.totalSeconds()
    assert td.totalSeconds() == 86401

    after = before + 1.years
    td = after - before
    echo before, " ", after, " ", td
    assert td.days in {365, 366} and td.seconds > 0

    after = before + 10.years
    td = after - before
    echo before, " ", after, " ", td

  echo ""
  let full_corr = LeapSecondData[^1][1] - LeapSecondData[0][1]
  let last_corr = full_corr - 1 # because the last leapsecond is not yet inserted
  var before = initZonedDateTime(localFromTime(LeapSecondData[0][0] + NTP_EPOCH, tz), tz)
  var after = initZonedDateTime(localFromTime(LeapSecondData[^1][0]  + full_corr + NTP_EPOCH, tz), tz)
  let td = after - before
  echo before, " ", after, " ", td, " ", td.seconds, " leap seconds in between..."
  assert td.seconds == full_corr - 1

when not defined(useLeapSeconds):
  {.error: "works only if compiled with: -d:useLeapSeconds".}

test_86401_days()