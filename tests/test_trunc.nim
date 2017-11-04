import ZonedDateTime
import strutils

proc test_trunc() =
  var n = now()
  echo n
  echo n.trunc(taSecond)
  echo n.trunc(taMinute)
  echo n.trunc(taHour)
  echo n.trunc(taDay)
  var isowd = n.toISOWeekDate()
  isowd.weekday = 1
  echo n.trunc(taWeek), " ", fromOrdinal(toOrdinalFromISO(isowd))
  echo n.trunc(taMonth)
  echo n.trunc(taQuarter)
  echo n.trunc(taYear)
  echo n.trunc(taDecade)
  echo n.trunc(taCentury)

test_trunc()