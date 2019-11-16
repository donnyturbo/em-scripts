SELECT substring_index(sub_table1.groupName, '\\', 1) as 'Datacenter'
      ,substring_index(sub_table1.groupName, '\\', -1) as 'Cluster'
      ,IFNULL(ROUND(cpu_cap/1000,1),0) as 'CPU Capacity (GHz)'
      ,IFNULL(ROUND((mem_cap/1048576),1),0) as 'Mem Capacity (GB)'
      ,IFNULL(ROUND(stor_cap/1024,1),0) as 'Storage Capacity (GB)'
      ,IFNULL(ROUND(cpu_used/1000,1),0) as 'CPU Used (GHz)'
      ,IFNULL(ROUND((mem_used/1048576),1),0) as 'Mem Used (GB)'
      ,IFNULL(ROUND(stor_used/1024,1),0) as 'Storage Used (GB)'

FROM
    (SELECT snapshot_time
           ,substring(grp.display_name,5) as groupName
           ,sum(cpu_used) as cpu_used
           ,sum(mem_used) as mem_used
           ,sum(cpu_cap) as cpu_cap
           ,sum(mem_cap) as mem_cap
    
    FROM
        (SELECT ps.uuid
               ,ps.snapshot_time
               ,MAX(IF(ps.property_type = 'CPU', (ps.avg_value*ps.capacity), NULL)) AS cpu_used
               ,MAX(IF(ps.property_type = 'Mem', (ps.avg_value*ps.capacity), NULL)) AS mem_used
               ,MAX(IF(ps.property_type = 'CPU', ps.capacity, NULL)) AS cpu_cap
               ,MAX(IF(ps.property_type = 'Mem', ps.capacity, NULL)) AS mem_cap
    
        FROM pm_stats_by_month ps
        WHERE ps.snapshot_time = LAST_DAY(SUBDATE(CURDATE(), INTERVAL 1 MONTH))
        GROUP BY 1,2) as a
    LEFT JOIN entities e on e.uuid = a.uuid and e.creation_class = 'PhysicalMachine'
    LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
    LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
    LEFT JOIN entities grp ON grp.id = eas.entity_entity_id
    WHERE grp.name like 'GROUP-PMsByCluster_%'
    AND eas.name = 'consistsOf'
    GROUP BY 2,1) as sub_table1

JOIN 
    (SELECT snapshot_time
           ,substring(grp.display_name,9) as groupName
           ,sum(stor_used) as stor_used
           ,sum(stor_cap) as stor_cap
    
    FROM
        (SELECT ds.snapshot_time
               ,ds.uuid as uuid
               ,MAX(IF(ds.property_type = 'StorageAmount', ds.avg_value*ds.capacity, NULL)) AS stor_used
               ,MAX(IF(ds.property_type = 'StorageAmount', ds.capacity, NULL)) AS stor_cap
    
        FROM ds_stats_by_month ds
        WHERE ds.snapshot_time = LAST_DAY(SUBDATE(CURDATE(), INTERVAL 1 MONTH))
          AND property_subtype = 'utilization'
        GROUP BY 1,2) as a
    LEFT JOIN entities e on e.uuid = a.uuid and e.creation_class = 'Storage'
    LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
    LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
    LEFT JOIN entities grp ON grp.id = eas.entity_entity_id
    WHERE grp.name like 'GROUP-STsByCluster_%'
    AND eas.name = 'consistsOf'    
    GROUP BY 2,1) as sub_table2
ON sub_table1.groupName = sub_table2.groupName and sub_table1.snapshot_time = sub_table2.snapshot_time
ORDER BY 2,1