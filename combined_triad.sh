#! /bin/bash
mysql -u root -pvmturbo vmtdb < /srv/tomcat/script/control/em-scripts/gen_scripts_data/triad/historical_triad.sql
python3 ./triad_with_current_actions.py
rm /tmp/systemd-private*mariadb.service*/tmp/historical_triad.csv