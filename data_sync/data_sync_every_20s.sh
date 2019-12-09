#!/bin/bash

Date=$("date" +%Y%m%d)
Time=$("date" +%H:%M:%S)

YN_Check_File="/home/batch/data_sync_every_20s_YN.txt"
Error_Log_File="/home/batch/log/sync_source_error.log"

if [ -r $YN_Check_File ]; then
        echo "Y/N Check File Exist"
else
        echo "[$Date][$Time] | Data_145 | Finish Program | Y/N Check File NOT Exist" >> $Error_Log_File
        exit 0
fi

YN_Check=$("cat" $YN_Check_File | grep Data_145 | awk '{print $2}' )

if [ Y == $YN_Check ]; then
        echo "[$Date][$Time] | Data_145 | Finish Program | Same Process Is Already Running" >> $Error_Log_File
        exit 0
elif [ N == $YN_Check ]; then
        sed -i 's/Data_145 N/Data_145 Y/' $YN_Check_File
        sleep 3
        rsync -az --delete --bwlimit=4096 --exclude-from '/home/KTSRC/sync_pattern_DATA.txt' -e ssh root@45.58.10.90:/home/KTSRC/data/ /home/KTSRC/data/
        sed -i 's/Data_145 Y/Data_145 N/' $YN_Check_File
fi

exit 0
