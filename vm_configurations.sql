SELECT SUBSTRING(SUBSTRING_INDEX(grp.display_name, '\\', 1), 5) as 'Datacenter'
      ,SUBSTRING_INDEX(grp.display_name, '\\', -1) as 'Cluster'
      ,SUBSTRING(grpp.display_name, 5) as 'Host'
      ,e.display_name as 'VM Name'
      ,IF(vcpu_used = 0 and vmem_used = 0, 'Off', 'On') as 'State'
      ,ROUND(vcpu_cap/1000, 2) as 'CPU Capacity (GHz)'
      ,ROUND(vmem_cap/1024/1024, 2) as 'Mem Capacity (GB)'
      ,ROUND(stor_cap/1024, 2) as 'Storage Capacity (GB)'
      ,ROUND(vcpu_used/1000, 2) as 'CPU Used (GHz)'
      ,ROUND(vmem_used/1024/1024, 2) as 'Mem Used (GB)'
      ,ROUND(stor_used/1024, 2) as 'Storage Used (GB)'
  FROM
       (SELECT uuid
              ,MAX(IF(property_type = 'VCPU', avg_value, 0)) as vcpu_used
              ,MAX(IF(property_type = 'CPUProvisioned', avg_value, NULL)) as vcpu_cap
              ,MAX(IF(property_type = 'VMem', avg_value, 0)) as vmem_used
              ,MAX(IF(property_type = 'MemProvisioned', avg_value, NULL)) as vmem_cap
              ,MAX(IF(property_type = 'StorageAmount', avg_value, NULL)) as stor_used
              ,MAX(IF(property_type = 'StorageProvisioned', avg_value, NULL)) as stor_cap
          FROM vm_stats_by_month
         WHERE snapshot_time = LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
           AND property_subtype = 'used'
         GROUP BY 1) as a
  JOIN entities e on e.uuid = a.uuid and e.creation_class = 'VirtualMachine'
  LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  LEFT JOIN entities grp ON grp.id = eas.entity_entity_id
  LEFT JOIN entity_assns_members_entities eamee ON eamee.entity_dest_id = e.id
  LEFT JOIN entity_assns eass ON eass.id = eamee.entity_assn_src_id
  LEFT JOIN entities grpp ON grpp.id = eass.entity_entity_id
 WHERE eas.name = 'consistsOf'
   AND eass.name = 'consistsOf'
   AND grp.name LIKE 'GROUP-VMsByCluster\_%'
   AND grpp.name LIKE 'GROUP-VMs\_%'
 GROUP BY e.uuid
 ORDER BY 1,2,4
