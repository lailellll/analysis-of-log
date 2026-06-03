sqoop export \
--connect "jdbc:mysql://node1:3306/mytest?useSSL=false&characterEncoding=utf8" \
--username root \
--password root123456 \
--table ads_user_city \
--export-dir /behavior/ads/ads_user_city \
--input-fields-terminated-by '\t' \
--num-mappers 1
