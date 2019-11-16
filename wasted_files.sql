select * from
(select 'Datacenter'
      ,'Cluster'
      ,'vCenter'
      ,'Datastore Name'
      ,'File Date'
      ,'File Size'
      ,'File Path'
union
(select *
from
(select substring(substring_index(grp.display_name, '\\', 1), 9) as Datacenter
       ,substring_index(grp.display_name, '\\', -1) as Cluster
       ,substring_index(substring_index(grp.name, '_', -1), '\\', 1) as vCenter
       ,datastore_name
       ,max(from_unixtime(substr(value,l1+1,l2-l1-1)/1000,'%Y-%m-%d')) as file_date
       ,convert(sum(left(value, l1-1)) / 1024 / 1024, decimal(18,2)) as file_size
       ,substring(value,l2+1) as file_path
from (select display_name as datastore_name
            ,value
            ,locate(':',value) as l1
            ,locate(':',value,locate(':',value)+1) as l2
            ,entities.id as eid
        from entity_attrs,
           entities
        where
         entity_attrs.name = 'wastedFile'
         and entity_attrs.entity_entity_id = entities.id) as x
JOIN entity_assns_members_entities eame ON eame.entity_dest_id = x.eid
JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id AND eas.name = 'consistsOf'
JOIN entities grp ON grp.id = eas.entity_entity_id AND grp.name like 'GROUP-STsByCluster\_%'
group by
        datastore_name, file_path
order by
        datastore_name, file_size DESC, file_path) as t1
where t1.file_size > 100
order by t1.datastore_name, t1.file_size DESC, t1.file_path)) as t2
INTO OUTFILE '/tmp/orphaned_files.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'