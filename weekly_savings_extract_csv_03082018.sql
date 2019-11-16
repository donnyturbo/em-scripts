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
        ,count(IF(action_type = '16' and (details LIKE 'Scale Up VMEM%' OR details LIKE 'Scale Up VCPU%'), target_object_uuid, NULL)) as 'Upsizes'
        ,count(IF(action_type = '16' and (details LIKE 'Scale Down VMEM%' OR details LIKE 'Scale Down VCPU%'), target_object_uuid, NULL)) as 'Downsizes'
FROM actions a
JOIN entities e on e.uuid = target_object_uuid
JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
JOIN entities grp ON grp.id = eas.entity_entity_id
WHERE action_state in ('4')
AND eas.name = 'consistsOf'
AND grp.name like 'GROUP-VMsByCluster\_%'
GROUP BY 1
ORDER BY ifnull(create_time, update_time))
) as csv_alias
INTO OUTFILE '/tmp/weekly_savings_extract.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'