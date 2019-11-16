SELECT 'Start Date'
      ,'End Date'
      ,'Location'
      ,'Entity Type'
      ,'Category'
      ,'Risk Type'
      ,'Risks Avoided'
      ,'Actions Completed'
      ,'Actions Outstanding'
UNION
SELECT date(min(start_time)) as 'Start Date'
      ,date(max(end_time)) as 'End Date'
      ,location as 'Location'
      ,substring_index(name, '::', 1) as 'Entity Type'
      ,substring_index(n.category, '/', -1) as 'Category'
      ,IF(name like '%Q%VCPU%', 'ReadyQueue Congestion', 
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical Mem %', 'Mem Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical CPU %', 'CPU Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical MemProv%', 'MemProvisioned Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical CPUProv%', 'CPUProvisioned Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical Net%', 'NetThroughput Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical IO%', 'IOThroughput Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical Ready%', 'ReadyQueue Congestion',
          IF(substring_index(name, '::', -1) = 'Physical Machine Congestion' and description like '%Critical Balloon%', 'Ballooning Congestion',
          IF(substring_index(name, '::', -1) = 'Storage Congestion' and description like '%Storage Amount%', 'StorageAmount Congestion',
          IF(substring_index(name, '::', -1) = 'Storage Congestion' and description like '%Storage Access%', 'StorageAccess Congestion', 
          IF(substring_index(name, '::', -1) = 'Storage Congestion' and description like '%Storage Latency%', 'StorageLatency Congestion',
          IF(substring_index(name, '::', -1) = 'Storage Congestion' and description like '%Storage Provisioned%', 'StorageProvisioned Congestion',
          IF(substring_index(name, '::', -1) = 'Misconfiguration' and description like '%Missing data%', 'Management Agent Could not be Reached',
          substring_index(name, '::', -1))))))))))))))) as 'Risk Type'
      ,count(IF(action_state = '4', n.id, NULL)) as 'Risks Avoided'
      ,IFNULL(sum(completed_actions),0) as 'Actions Completed'
      ,0 as 'Actions Outstanding'
  FROM notifications n
  JOIN 
    (SELECT notification_id
           ,action_state 
           ,count(completed_actions) as completed_actions
           ,min(start_time) as start_time
           ,max(end_time) as end_time
           ,location          
       FROM
        (SELECT notification_id
               ,action_state
               ,IF(action_state = '4', action_uuid, NULL) as completed_actions
               ,IFNULL(min(create_time), min(update_time)) as start_time
               ,IFNULL(max(create_time), max(update_time)) as end_time
               ,IF(target_object_uuid in (select distinct uuid from vm_spend_by_month) or target_object_uuid in (select distinct uuid from vm_spend_by_day)
                   OR target_object_uuid in (select distinct uuid from app_spend_by_month) or target_object_uuid in (select distinct uuid from app_spend_by_day), 
                   'CLOUD', 'ONPREM') as location
           FROM actions a
          WHERE create_time > '2017-01-01 00:00:00'
            AND action_state = '4'
            AND action_uuid is not null
          GROUP BY action_uuid, notification_id) as a
      GROUP BY notification_id,location) a 
   ON n.id = a.notification_id
WHERE n.clear_time > '2017-01-01 00:00:00'
  AND n.category IN ('MarketProblem/Performance Assurance','MarketProblem/Efficiency Improvement','MarketProblem/Compliance')
GROUP BY 6, location, 4 
ORDER BY location, 6, 4
 INTO OUTFILE '/tmp/historical_triad.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'