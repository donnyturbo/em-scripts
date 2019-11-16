SELECT * FROM (
(SELECT 'Week/Year'
          ,'Host Moves'
          ,'Storage Moves'
          ,'Host Suspensions'
          ,'Upsizes'
          ,'Downsizes')
UNION
(SELECT  date_format(ifnull(create_time, update_time), '%U/%Y') as 'Week/Year'
        ,count(IF(action_type = '2', target_object_uuid, NULL)) as 'Host Moves'
        ,count(IF(action_type = '7', target_object_uuid, NULL)) as 'Storage Moves'
        ,count(IF(action_type = '3', target_object_uuid, NULL)) as 'Host Suspensions'
        ,count(IF(action_type = '16' and (details LIKE 'Increase VMEM capacity%' OR details LIKE 'Increase VCPU capacity%'), target_object_uuid, NULL)) as 'Upsizes'
        ,count(IF(action_type = '16' and (details LIKE 'Reduce VMEM capacity%' OR details LIKE 'Reduce VCPU capacity%'), target_object_uuid, NULL)) as 'Downsizes'
FROM actions a
WHERE action_state = '4'
GROUP BY 1
ORDER BY ifnull(create_time, update_time))
) as csv_alias
INTO OUTFILE '/tmp/weekly_savings_extract.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'