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

proc test_ls_transitions() =
  let tz = initTZInfo("/usr/share/zoneinfo/right/Zulu", tzOlson)

  let base_lsinfo = LeapSecondData[0]
  
  for i in 1..high(LeapSecondData):
    let lsinfo = LeapSecondData[i]
    let ttime = lsinfo[0]
    var ep_ttime = ttime + NTP_EPOCH
    ep_ttime -= 2
    let corr = lsinfo[1] - base_lsinfo[1]
    let transitionTime = initZonedDateTime(localFromTime((ep_ttime + corr - 1).float64, tz), tz)
    echo ttime, " ", ep_ttime, " ", corr, " ", transitionTime
    for i in 1..4:
      #let tmp = transitionTime + initTimeStamp(seconds = i.float)
      #let tmp = transitionTime + initTimeDelta(seconds = i.float)
      let tmp = transitionTime + i.seconds
      case i
      of 1:
        echo tmp
        assert tmp.second == 59
      of 2:
        echo tmp
        assert tmp.second == 60
      of 3:
        echo tmp
        assert tmp.second == 0
      of 4:
        echo tmp
      else:
        assert false

when not defined(useLeapSeconds):
  {.error: "works only if compiled with -d:useLeapSeconds".}

test_ls_transitions()