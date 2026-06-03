show databases;
create database behavior;
use behavior;
select current_database();

-- ods用外部表
drop table if exists ods_behavior_log;
create external table if not exists ods_behavior_log(
    line string
)partitioned by(dt string) location '/behavior/ods/ods_behavior_log';
select * from ods_behavior_log;
-- 这一个没问题 写脚本批量导入
load data inpath '/origin/log/2022-08-08' overwrite into table ods_behavior_log partition(dt='2022-08-08');
select * from ods_behavior_log where dt='2022-08-09';
select count(1) from ods_behavior_log; -- 70000

-- ip处理 以及 url处理
add jar /home/hadoop/hive_udf_custom-1.0-SNAPSHOT.jar;
create temporary function get_city_by_ip as 'org.example.myUDF.Ip2Loc';
create temporary function url_trans_udf as 'org.example.myUDF.UrlHandler';


-- dwd明细表
drop table if exists dwd_behavior_log;
create table if not exists dwd_behavior_log(
    client_ip string comment '客户端IP',
    device_type string comment '设备类型',
    type string comment '上网类型 4G 5G WiFi',
    device string comment '设备ID',
    url string comment '访问的资源路径',
    area string comment '地区信息',
    ts bigint comment '时间戳'
)comment '用户行为日志表'
partitioned by(dt string)
stored as ORC
location '/behavior/dwd/dwd_behavior_log'
tblproperties ("orc.compress"="snappy");
select * from dwd_behavior_log;

set hive.exec.dynamic.partition.mode=nonstrict; -- 开启动态分区
insert into table dwd_behavior_log partition(dt)
select get_json_object(line,'$.client_ip'),
       get_json_object(line,'$.device_type'),
       get_json_object(line,'$.type'),
       get_json_object(line,'$.device'),
       url_trans_udf(get_json_object(line,'$.url')),
       split(get_city_by_ip(get_json_object(line,'$.client_ip')),'_')[0], -- 只提取地区
       get_json_object(line,'$.time'),
       dt
       from ods_behavior_log;
select * from dwd_behavior_log;

-- dws汇总层
drop table if exists dws_behavior_log;
create table if not exists dws_behavior_log(
   client_ip string comment '客户端IP',
   device_type string comment '设备类型',
   type string comment '上网类型 4G 5G WiFi',
   device string comment '设备ID',
   url string comment '访问的资源路径',
   city string comment '城市',
   ts bigint comment '时间戳'
)comment '页面启动日志表'
partitioned by (dt string)
stored as ORC
location '/behavior/dws/dws_behavior_log'
tblproperties ("orc.compress"="snappy");

insert overwrite table dws_behavior_log partition(dt)
select client_ip,device_type,type,device,url,area,ts,dt from dwd_behavior_log;

select * from dws_behavior_log tablesample(10k);

-- dim维度表
-- 统计每天的用户访问量、每个季度的用户访问量、每个月的访问情况
-- 每个城市的用户访问情况
-- 每个省份的用户访问情况
drop table if exists dim_date;
create table if not exists dim_date(
    date_id string comment '日期',
    week_id string comment '周',
    week_day string comment '星期',
    day string comment '一个月的第几天',
    month string comment '第几个月',
    quarter string comment '第几个季度',
    year string comment '年度',
    is_workday string comment '是否是工作日',
    holiday_id string comment '国家法定假日'
)row format delimited fields terminated by '\t'
lines terminated by '\n'
location '/behavior/dim/dim_date';

select * from dim_date;

drop table if exists dim_area;
create table if not exists dim_area(
    city string comment '城市',
    province string comment '省份',
    area string comment '地区'
) row format delimited fields terminated by '\t'
lines terminated by '\n'
location '/behavior/dim/dim_area';
select * from dim_area;

-- ADS
-- 用户城市分布
drop table if exists ads_user_city;
create external table if not exists ads_user_city(
    city string comment '城市',
    province string comment '省份',
    area string comment '区域',
    dt string comment '日期',
    count bigint comment '访问数量'
)comment '用户城市分布'
row format delimited fields terminated by '\t'
location '/behavior/ads/ads_user_city';

insert into table ads_user_city
select t1.city city,t2.province province,t2.area area,t1.dt,count(*) as `count` from
dws_behavior_log t1 left join dim_area t2 on t1.city = t2.city group by t1.city,t2.province,t2.area,t1.dt;

-- 每个网站的上网模式
drop table if exists ads_visit_type;
create external table if not exists ads_visit_type(
    url string comment '访问地址',
    type string comment '访问模式 4G 5G WiFi',
    dt string comment '日期',
    month string comment '月度',
    quarter string comment '季度',
    `count` bigint comment '统计数量'
)comment '网站访问的上网模式分布'
row format delimited fields terminated by '\t'
location '/behavior/ads/ads_visit_type';

insert overwrite table ads_visit_type
select t1.url,t1.type,t1.dt,t2.month,t2.quarter,count(*) as `count` from
dws_behavior_log t1 left join dim_date t2 on t1.dt=t2.date_id group by t1.url,t1.type,t1.dt,t2.month,t2.quarter;
select * from ads_visit_type;
