mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/dev/VM_Density_Monthly.sql
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/risks_and_actions_6_0_updated.sql
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/total_moves/weekly_savings_extract_csv.sql
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/guestos/clus-host-vm.sql
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/idle_pw_off/idle-vm-duration_60_day.sql 
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/idle_pw_off/powered_off_vms_60_days.sql
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/risk_avoid/risks_avoided_since_start_of_year_csv.sql 
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/vm_density/vm_density_monthly.sql 
# Change working directory to scripts directory and run guestos script
cd /srv/tomcat/script/control/em-scripts/
python3.6 /srv/tomcat/script/control/em-scripts/gen_scripts_data/guestos/guestos.py
