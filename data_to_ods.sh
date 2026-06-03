if [ ${#} -ne 3 ];then
        echo "useage src1.sh start_date end_date hive_home"
        exit
fi

EXPORT_START_DATE=${1}
EXPORT_END_DATE=${2}
i=${EXPORT_START_DATE}
HIVE_HOME=${3}

while [[ ${i} < $(date -d "+1 day ${EXPORT_END_DATE}" +%Y-%m-%d) ]]
do
        ${HIVE_HOME} -e  "use behavior; load data inpath '/origin/log/${i}' overwrite into table ods_behavior_log partition(dt='${i}')"         
        echo ${i}
        i=$(date -d "+1 day ${i}" +%Y-%m-%d)
done
