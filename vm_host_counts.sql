SELECT SUBSTRING_INDEX(a.cluster, '\\', 1) as 'Datacenter'
      ,SUBSTRING_INDEX(a.cluster, '\\', -1) as 'Cluster'
      ,pm_count as 'Host Count'
      ,vm_count as 'VM Count'
FROM
(SELECT SUBSTRING(grp.display_name,5) as cluster
      ,count(e.uuid) as vm_count
  FROM entities e
  LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  LEFT JOIN entities grp ON grp.id = eas.entity_entity_id
 WHERE eas.name = 'consistsOf'
   AND grp.name LIKE 'GROUP-VMsByCluster\_%'
   AND e.creation_class = 'VirtualMachine'
 GROUP BY 1) as a
JOIN
(SELECT SUBSTRING(grp.display_name,5) as cluster
      ,count(e.uuid) as pm_count
  FROM entities e 
  LEFT JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  LEFT JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  LEFT JOIN entities grp ON grp.id = eas.entity_entity_id
 WHERE eas.name = 'consistsOf'
   AND grp.name LIKE 'GROUP-PMsByCluster\_%'
   AND e.creation_class = 'PhysicalMachine'
 GROUP By 1) as b
ON a.cluster = b.cluster