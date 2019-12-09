#!/bin/bash
#
# httpd.conf
# LogFormat "%h|@%t|@%P|@%>s|@%T|@%D|@%U|@%B|@%f|@%q|@\"%r\"|@\"%{Referer}i\"|@\"%{User-Agent}i\"" combined
#
# httpd-vhosts.conf
# CustomLog "|/home/apache/bin/rotatelogs -l /home/apache/logs/access_log-%Y%m%d 86400" combined Env=!DontLog
#
ApacheLogFile=/home/apache/logs/access_log
TmpFile=/home/apache/logs/tmp.log
BestclickFile=/home/data/bestclick.log
FinalLogFile=/home/data/bestclick50.log
FinalLogAppFile=/home/data/bestclick50_app.log
FinalLogAppFile2=/home/data/bestclick300.log
Start=0
PastHour=1

Time=$("/bin/date" +%Y:%m:%h:%d:%H --date ''$PastHour' hour ago')
Date=$("/bin/echo" $Time | "/bin/cut" -d: -f1,2,4 | "/bin/sed" 's/://g')
Year=$("/bin/echo" $Time | "/bin/cut" -d: -f1)
MonthChar=$("/bin/echo" $Time | "/bin/cut" -d: -f3)
Day=$("/bin/echo" $Time | "/bin/cut" -d: -f4)
Hour=$("/bin/echo" $Time | "/bin/cut" -d: -f5)
DayChar=$("/bin/date" +%a) && if [ $DayChar == "Mon" ]; then DChkCnt=2; else DChkCnt=1; fi

for((i=0;i<=$DChkCnt;i++))
do
   DayAgo[$i]=$("/bin/date" +%Y%m%d -d ""$i" day ago")
done

# Gathering article lanes from 5 hours ago to now and excluding the article lanes from bot.
for((i=$Start;i<=$PastHour;i++))
do
   "/bin/cat" $ApacheLogFile-$Date | "/bin/grep" $Day\/$MonthChar\/$Year:$Hour: | "/bin/grep" -v bot | "/bin/awk" -F"\\\|@" '{print $7}' | "/bin/grep" ^\/article\/'[0-9]\{8\}'\/'[0-9]\{7\}'$ >> $TmpFile
   Hour=$("/usr/bin/expr" $Hour + 1)
   H=$("/bin/echo" -n $Hour | "/usr/bin/wc" -c) && if [ $H == 1 ]; then Hour=0$("/bin/echo" $Hour); else Hour=$("/bin/echo" $Hour); fi
   if [ $Hour == 24 ]; then
      Hour=00
      Date=$("/bin/date" +%Y%m%d)
      Year=$("/bin/date" +%Y)
      MonthChar=$("/bin/date" +%h)
      Day=$("/bin/date" +%d)
   fi
done

"/bin/cat" $TmpFile | "/bin/sort" | "/usr/bin/uniq" -cd | "/bin/sed" -e 's;^.*  ;;' | "/bin/sed" -e 's/\ /\t/' | "/bin/sort" -nr > $BestclickFile
# Check BeskclickFile Count
# If firstly made bestblick.log file's count if less than 100, retry to add article list into the tmp.log file from (PastHour + 1) hour until over 100

while [ TRUE ]
do
   BestCnt=$("/bin/cat" $BestclickFile | "/usr/bin/wc" -l)
   if [ $BestCnt -lt 300 ]; then
      PastHour=$("/usr/bin/expr" $PastHour + 1)
      Time=$("/bin/date" +%Y:%m:%h:%d:%H --date ''$PastHour' hour ago')
      Date=$("/bin/echo" $Time | "/bin/cut" -d: -f1,2,4 | "/bin/sed" 's/://g')
      Year=$("/bin/echo" $Time | "/bin/cut" -d: -f1)
      MonthChar=$("/bin/echo" $Time | "/bin/cut" -d: -f3)
      Day=$("/bin/echo" $Time | "/bin/cut" -d: -f4)
      Hour=$("/bin/echo" $Time | "/bin/cut" -d: -f5)
      "/bin/cat" $ApacheLogFile-$Date | "/bin/grep" $Day\/$MonthChar\/$Year:$Hour: | "/bin/grep" -v bot | "/bin/awk" -F"\\\|@" '{print $7}' | "/bin/grep" ^\/article\/'[0-9]\{8\}'\/'[0-9]\{7\}'$ >> $TmpFile
      "/bin/cat" $TmpFile | "/bin/sort" | "/usr/bin/uniq" -cd | "/bin/sed" -e 's;^.*  ;;' | "/bin/sed" -e 's/\ /\t/' | "/bin/sort" -nr > $BestclickFile
      BestCnt=$("/bin/cat" $BestclickFile | "/usr/bin/wc" -l)
   else
      break
   fi
done

sleep 10

# Check every row's date if the date is later than 2 days. If so remove the article lane.
# But only Monday, valid until 3 days ago because Sunday have not enough articles.
echo "DChkCnt : "$DChkCnt
for((i=1;i<=$BestCnt;i++))
do
   echo "********************"
   echo "BestCnt : "$BestCnt
   CheckDate=$("/bin/cat" $BestclickFile | "/bin/sed" -n ""$i"p" | "/bin/awk" -F"/" '{print $3}')
   Article=$("/bin/cat" $BestclickFile | "/bin/sed" -n ""$i"p" | "/bin/awk" '{print $2}')
   echo "Article : "$Article
   echo "CheckDate : "$CheckDate
   for((j=0;j<=$DChkCnt;j++))
   do
      echo "Try [$j] / All [$DChkCnt]"
      echo "DayAgo [${DayAgo[$j]}] == CheckDate [$CheckDate]"
      if [ ${DayAgo[$j]} == $CheckDate ]; then
         echo "[$Article] is Passed"
         break
      else
         if [ $j -eq $DChkCnt ]; then
            echo "[$Article] is Removed <<===="
            "/bin/sed" -i ''$i'd' $BestclickFile
            BestCnt=$("/usr/bin/expr" $BestCnt - 1)
            i=$("/usr/bin/expr" $i - 1)
         else
            echo "[$Article] is Passed"
         fi
      fi
   done
done

"/usr/bin/head" -n 100 $BestclickFile > $FinalLogFile
"/usr/bin/head" -n 150 $BestclickFile > $FinalLogAppFile
"/usr/bin/head" -n 300 $BestclickFile > $FinalLogAppFile2
"/bin/sed" -i -e 's/article\/[0-9]\{4\}/&\//g' -e 's/article\/[0-9]\{4\}\/[0-9]\{2\}/&\//g' $FinalLogAppFile
"/bin/chown" dev:dev $FinalLogFile
"/bin/chown" dev:dev $FinalLogAppFile

"/bin/cp" $BestclickFile $BestclickFile.tmp
"/bin/cp" $TmpFile $TmpFile.tmp

"/bin/rm" -f $BestclickFile
"/bin/rm" -f $TmpFile

exit 0
