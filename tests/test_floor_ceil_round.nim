import ZonedDateTime

var n = now()
var ti = 17 * 1.hours + 25.hours * 3 - 123.minutes
echo n
echo ti
echo n + ti
echo ti * 2
echo trunc(n - ti * 2, taMinute).toTimeInterval()

echo floor(n, 1.years)
echo floor(n, 1.months)
echo floor(n, 1.days)
echo floor(n, 7.days)

n = initDateTime(year = 2013, 2, 13, 14, 44, 60)
echo ""
echo floor(n, 1.hours)
echo floor(n, 15.minutes)
echo ""
echo "floor"
var tresult: DateTime
tresult = floor(initDateTime(1985, 9, 30), 1.months)
echo tresult
assert $tresult == "1985-09-01T00:00:00"
tresult = floor(initDateTime(1985, 8, 16), 1.months)
echo tresult
assert $tresult == "1985-08-01T00:00:00"
tresult = floor(initDateTime(2013, 2, 13, 0, 31, 20), 15.minutes)
echo tresult
assert $tresult == "2013-02-13T00:30:00"
tresult = floor(initDateTime(2016, 8, 6, 12, 0, 0), 1.days)
echo tresult
assert $tresult == "2016-08-06T00:00:00"
echo ""
echo "ceil"
tresult = ceil(initDateTime(2013, 2, 13, 0, 31, 20), 15.minutes)
echo tresult
assert $tresult == "2013-02-13T00:45:00"
tresult = ceil(initDateTime(2016, 8, 6, 12, 0, 0), 1.days)
echo tresult
assert $tresult == "2016-08-07T00:00:00"
echo ""
echo "rounding"
tresult = round(initDateTime(1985, 8, 16), 1.months)
echo tresult
assert $tresult == "1985-08-01T00:00:00"
tresult = round(initDateTime(1985, 8, 17), 1.months)
echo tresult
assert $tresult == "1985-09-01T00:00:00"
tresult = round(initDateTime(2013, 2, 13, 0, 31, 20), 15.minutes)
echo tresult
assert $tresult == "2013-02-13T00:30:00"
tresult = round(initDateTime(2016, 8, 6, 12, 0, 0), 1.days)
echo tresult
assert $tresult == "2016-08-07T00:00:00"

