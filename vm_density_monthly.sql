SELECT 'Datacenter\\Cluster'
      ,'Number of VMs'
      ,'Headroom VMs'
      ,'Number of Hosts'
      ,'Average VM Density'
      ,'Date'
 UNION
SELECT substring(csd.group_name, 5) as 'Datacenter\\Cluster'
      ,csd.num_vms as 'Number of VMs'
      ,csd.desired_vms - csd.current_vms as 'Headroom VMs'
      ,csd.num_hosts as 'Number of Hosts'
      ,csd.num_vms / csd.num_hosts as 'Average VM Density'
      ,csd.recorded_on as 'Date'
  FROM (
  	SELECT cm.group_name
    		  ,count(distinct member_uuid) as num_vms
    		  ,max(if(property_type = 'Host' and property_subtype = 'currentNumHosts', value, NULL)) as num_hosts
    		  ,max(if(property_type = 'Host' and property_subtype = 'DesiredVMs', value, NULL)) as desired_vms
          ,max(if(property_type = 'Host' and property_subtype = 'CurrentVMs', value, NULL)) as current_vms
    		  ,csd.recorded_on
		  FROM cluster_stats_by_month csd
		  JOIN cluster_members cm
		    ON substring_index(cm.internal_name, '_', -1) = substring_index(csd.internal_name, '_', -1)
		       AND cm.recorded_on = end_of_month(csd.recorded_on)
		 WHERE csd.recorded_on  >= (select min(recorded_on) from cluster_stats_by_month)
		   AND cm.recorded_on >= (select min(recorded_on) from cluster_stats_by_month)
		   AND csd.property_type = 'Host'
		   AND cm.group_type = 'VirtualMachine'
		 GROUP BY 1, recorded_on
		) csd
INTO OUTFILE '/tmp/vm_density_monthly.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '\\'
LINES TERMINATED BY '\n'
