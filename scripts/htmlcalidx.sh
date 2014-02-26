#!/bin/bash

TODOM=${TODOM:-`date +%d`}
TOMONTH=${TOMONTH:-`date +%m`}
YEAR=${YEAR:-`date +%Y`}
MONTH=${MONTH:-1}
MONTHABV=([1]=Jan [2]=Feb [3]=Mar [4]=Apr  [5]=May  [6]=Jun \
          [7]=Jul [8]=Aug [9]=Sep [10]=Oct [11]=Nov [12]=Dec)

echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">'
echo '<html>'
echo '<head>'
echo "  <title>apt/ibot/infobot/purl logs for $YEAR</title>"
echo '  <link rel="shortcut icon" href="/favicon.ico">'
echo '</head>'
echo '<body>'

today=`date -d "yesterday" +%Y%m%d`
subdirs=`find \#* -maxdepth 0 -type d 2>/dev/null`
if [ -n "$subdirs" ] ; then
  echo '<h1>Channels (l for latest)</h1>'
  #echo "<table>"
  echo '<p>'
  for subdir in $subdirs ; do
    if [ "$subdir" != "stats" ] ; then
     subdirhtml=`echo \$subdir | sed -e 's/#/%23/'`;
     latest=`(cd $subdir ; ls [0-9]* 2>/dev/null| tail -n 1 | sed -e 's/.html.gz//')`
     if [ "$latest" = "$today" ] ; then
       #echo "<tr><td><a href=\"$subdirhtml\">$subdir</a></td><td><a href=\"$subdirhtml/$latest.html.gz\">$latest</a></td></tr>"
       echo "<a href=\"$subdirhtml\">$subdir</a>(<a href=\"$subdirhtml/$latest.html.gz\">l</a>)"
     fi
    fi
  done
  echo '</p>'
  #echo "</table>"
fi
#if [ -n "$subdirs" ] ; then
#  echo "<h1>Channels</h1>"
#  echo "<ul>"
#  for subdir in $subdirs ; do
#    if [ "$subdir" != "stats" ] ; then
#     latest=`(cd $subdir ; ls [0-9]* | tail -n 1 | sed -e 's/.html.gz//')`
#     echo "<li><a href=\"$subdir\">$subdir</a> <a href=\"$subdir/$latest.html.gz\">$latest</a>"
#    fi
#  done
#  echo "</ul>"
#fi

echo "<h1>$YEAR</h1>"
echo '<table>'
echo '  <tbody>'
echo '    <tr>'

while [ $MONTH -le $TOMONTH ]; do

  STARTDAY=`date -d "1 ${MONTHABV[$MONTH]} $YEAR" +%w`
  case $MONTH in
    2)
      ENDDOM=28
      ;;
    9|4|6|11)
      ENDDOM=30
      ;;
    *)
      ENDDOM=31
      ;;
  esac

  echo '      <td valign=top>'

  echo '        <table border=1>'
  echo '          <tbody>'
  echo "            <tr><td align=center colspan=7>${MONTHABV[$MONTH]}</td></tr>"
  echo '            <tr><td>Sun</td><td>Mon</td><td>Tue</td><td>Wed</td><td>Thu</td><td>Fri</td><td>Sat</td></tr>'

  DOM=${DOM:-1}
  DAY=0
  INCDOM=no
  SHOWDOM=no
  until [ $DAY -eq 0 -a "$INCDOM" = "done" ]; do
    if [ $DAY -eq 0 ]; then
      echo -n "            <tr>"
    fi

    if [ "$INCDOM" = "no" -a $DAY -eq $STARTDAY ]; then
      INCDOM=yes
      SHOWDOM=yes
    fi

    echo -n "<td>"
    if [ "$SHOWDOM" = "yes" ]; then
        FILE=`date -d "$DOM ${MONTHABV[$MONTH]} $YEAR" +%Y%m%d`.html.gz
        if [ -f "$FILE" ]; then
            echo -n "<a href=\"$FILE\">"$DOM"</a>"
          else
            echo $DOM
        fi
      else
        echo -n "&nbsp;"
    fi
    echo -n "</td>"

    if [ "$INCDOM" = "yes" ]; then
        if [ $DOM -eq $ENDDOM ]; then
            INCDOM="done"
            SHOWDOM=no
          else
            DOM=$(($DOM + 1))
            if [ $MONTH -eq $TOMONTH -a $DOM -gt $TODOM ]; then
              SHOWDOM=no
            fi
        fi
    fi

    DAY=$(($DAY + 1))
    if [ $DAY -eq 7 ]; then
      echo "</tr>"
      DAY=0
    fi
  done
  DOM=1

  echo '          </tbody>'
  echo '        </table>'

  echo '      </td>'

  if [ $MONTH -lt $TOMONTH ]; then
    if [ $(($MONTH % 4)) -eq 0 ]; then
      echo "    </tr>"
      echo "    <tr>"
    fi
  fi

  MONTH=$(($MONTH + 1))
done

echo '    </tr>'
echo '  </tbody>'
echo '</table>'

#echo '</body>'
#echo '</html>'
