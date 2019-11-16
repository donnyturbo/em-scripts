SELECT * FROM (
  (SELECT 'Week/Year'
          ,'Risks Avoided'
          ,'Count')

UNION
(SELECT date_format(clear_time, '%U/%Y') as 'Week/Year'
       ,IF(name like '%Q%VCPU%', 'ReadyQueue Congestion', substring_index(n.name, '::', -1)) as 'Risk Avoided'
       ,count(a.notification_id) 'Count'
  FROM
       (SELECT DISTINCT notification_id
          FROM actions 
         WHERE action_state = '0'
           AND action_type not in ('10','16')         # no resize or reconfigure actions
           AND (create_time BETWEEN '2017-1-1' AND NOW()
                OR update_time BETWEEN '2017-1-1' AND NOW())
       ) as a
  JOIN notifications n
    ON a.notification_id = n.id
   AND n.category in ('MarketProblem/Performance Assurance', 'MarketProblem/Compliance')
 GROUP BY 2,1
 ORDER By clear_time,2)
  ) as csv_alias
INTO OUTFILE '/tmp/risks_avoided_since_start_of_year.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'