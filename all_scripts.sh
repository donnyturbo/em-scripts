mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/dev/VM_Density_Monthly.sql
cd /srv/tomcat/script/control/em-scripts/
python3.6 /srv/tomcat/script/control/em-scripts/gen_scripts_data/guestos/guestos.py