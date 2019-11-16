SELECT * FROM
(SELECT snapshot_time, user_name, action_name, target_object_name, substring(vc.display_name,5) as cluster
  FROM audit_log_entries ale
  LEFT JOIN entities e on e.uuid = ale.target_object_uuid
  LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  LEFT JOIN entities vc ON vc.id = eas.entity_entity_id
 WHERE action_name IN ('Device Moved', 'Action Accepted', 'Action Completed')
   AND snapshot_time >= '2017-7-1'
   AND vc.name LIKE 'GROUP-VMsByCluster\_%'
   AND eas.name = 'consistsOf') as csv_alias

INTO OUTFILE '/tmp/audit_log.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'