sqoop export \
--connect "jdbc:mysql://node1:3306/mytest?useSSL=false&characterEncoding=utf8" \
--username root \
--password root123456 \
--table ads_visit_type \
--export-dir "/behavior/ads/ads_visit_type" \
--input-fields-terminated-by '\t' \
--num-mappers 1
