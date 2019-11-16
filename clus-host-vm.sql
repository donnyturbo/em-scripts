SELECT * FROM (
(SELECT 'Datacenter'
        ,'Cluster'
        ,'VM'
        ,'# VCPUs'
        ,'CPU Utilization %'
        ,'vRAM (GB)'
        ,'Mem Utilization %'
        ,'Storage Provisioned (GB)'
        ,'Storage Used (GB)'
        ,'Guest OS'
        ,'Assumed Usage %'
        ,'Host')
UNION
(SELECT substring_index(substring(grp.display_name,5),'\\', 1) as 'Datacenter'
       ,substring_index(grp.display_name,'\\', -1) as 'Cluster'
       ,e.display_name as 'VM'
       ,ROUND(vcpus,1) as '# VCPUs'
       ,IFNULL(ROUND((vcpu_avg/vcpu_cap)*100,2),0) as 'CPU Utilization %'
       ,IFNULL(ROUND(vmem_cap/1024/1024,2),0) as 'vRAM (GB)'
       ,IFNULL(ROUND((vmem_avg/vmem_cap)*100,2),0) as 'Mem Utilization %'
       ,ROUND(stor_provisioned/1024,2) as 'Storage Provisioned (GB)'
       ,ROUND(stor_used/1024,2) as 'Storage Used (GB)'
       ,a.uuid as 'Guest OS'
       ,100 as 'Assumed Usage'
       ,en.display_name as 'Host'

  FROM
    (SELECT uuid
            ,MAX(IF(property_type = 'MemProvisioned' and snapshot_time = (select max(snapshot_time) from vm_stats_by_day), producer_uuid, NULL)) as producer_uuid
            ,AVG(IF(property_type = 'VMem', avg_value, NULL)) as vmem_avg
            ,AVG(IF(property_type = 'VMem', capacity, NULL)) as vmem_cap
            ,AVG(IF(property_type = 'VCPU', avg_value, NULL)) as vcpu_avg
            ,AVG(IF(property_type = 'VCPU', capacity, NULL)) as vcpu_cap
            ,AVG(IF(property_type = 'numVCPUs', avg_value, NULL)) as vcpus
            ,AVG(IF(property_type = 'StorageProvisioned', avg_value, NULL)) as stor_provisioned
            ,AVG(IF(property_type = 'StorageAmount', avg_value, NULL)) as stor_used

       FROM vm_stats_by_day vs
      WHERE snapshot_time >= date_sub(CURDATE(), interval 60 day)
        AND property_subtype in ('used', 'numVCPUs')
      GROUP BY vs.uuid) as a
  JOIN entities e on e.uuid = a.uuid
  JOIN entities en on en.uuid = a.producer_uuid
  LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  LEFT JOIN entities grp ON grp.id = eas.entity_entity_id
  WHERE grp.name like 'GROUP-VMsByCluster\_%'
  AND eas.name = 'consistsOf'
 GROUP BY a.uuid)
) as csv_alias
INTO OUTFILE '/tmp/clus-host-vm.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'