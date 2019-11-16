SELECT 'Cluster'
      ,'Target'
      ,'Name'
      ,'Mem Allocated (GB)'
      ,'VCPUs Allocated'
      ,'Storage (MB)'
      ,'Days'
UNION
SELECT substring_index(vc.display_name,'\\', -1) as 'Cluster'
          ,substring_index(substring_index(vc.name, '_', -1), '\\', 1) as 'Target'
          ,e.display_name AS 'Name'
          ,ROUND(mem_cap/1024/1024,2) as 'Mem Allocated (GB)'
          ,ROUND(cpu_cap) as 'VCPUs Allocated'
          ,cur.st AS 'Storage (MB)'
          ,dur.dur AS 'Days'
  FROM (SELECT uuid
              ,MAX(IF(property_type = 'MemProvisioned' and property_subtype = 'used', avg_value, NULL)) as mem_cap
              ,MAX(IF(property_type = 'NumVCPUs', avg_value, NULL)) as cpu_cap
              ,SUM(IF(property_type = 'StorageAmount' and property_subtype = 'used', avg_value, 0)) AS st
          FROM vm_stats_by_day
         WHERE property_type IN ('VCPU', 'VMEM', 'StorageAmount', 'MemProvisioned', 'NumVCPUs')
           AND property_subtype in ('utilization', 'used', 'NumVCPUs')
           AND snapshot_time = SUBDATE(CURDATE(), 1)
         GROUP BY 1
        HAVING MAX(IF(property_type = 'VCPU' and property_subtype = 'utilization', max_value, 0)) < 0.05
           AND MAX(IF(property_type = 'VMem' and property_subtype = 'utilization', max_value, 0)) < 0.05
       ) cur
  JOIN entities e ON e.uuid = cur.uuid
  JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  JOIN entities vc ON vc.id = eas.entity_entity_id
  JOIN (SELECT uuid
              ,COUNT(snapshot_time) AS dur
              ,MAX(sa)
          FROM (SELECT uuid
                      ,snapshot_time
                      ,MAX(IF(property_type = 'StorageAmount', avg_value, NULL)) AS sa
                      ,MAX(IF(property_type = 'VMem' and property_subtype = 'utilization', max_value, NULL)) AS vm
                      ,MAX(IF(property_type = 'VCPU' and property_subtype = 'utilization', max_value, NULL)) AS vc
                  FROM vm_stats_by_day
                 WHERE property_type IN ('VCPU', 'VMEM', 'StorageAmount')
                 AND snapshot_time >= date_sub(CURDATE(),interval 60 day)
                 GROUP BY 1, 2
               ) t
         WHERE sa > 0
           AND (vm <= 0.05 AND vm > 0)
           AND (vc <= 0.05 AND vc > 0)
         GROUP BY 1
       ) dur ON dur.uuid = cur.uuid
  WHERE vc.name like 'GROUP-VMsByCluster\_%'
  AND eas.name = 'consistsOf'
  INTO OUTFILE '/tmp/idle-vm-duration_60_day.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'