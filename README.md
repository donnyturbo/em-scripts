# em-scripts

Do not use prep-system.sh or weekly.sh if the Turbo instance is not a standard install.  Meaning Turbo OVA or default install on RHEL.  The scripts expect specific locations 
 

Script installs for account decks 

Output of scripts will be placed in /srv/tomcat/data/repos/output this is captured as part of diags when run.  This will allow for customer to just run a diag and send to you for ease. 

 

ssh to turbo instance Example “ssh root@(ip) or hostname.domain.com 

Cut and paste command “mkdir /srv/tomcat/script/control/em-scripts” 

obtain em-scripts.tar.gz  “scp em-scripts.tar.gz root@10.16.172.210:/srv/tomcat/script/control/em-scripts” 

cut and paste cd /srv/tomcat/script/control/em-scripts 

Extract tar file cut and paste “tar -zxf em-scripts.tar.gz” 

Cut and paste “chmod 755 *” 

Cut and paste “./prep-system.sh (this will install python3.6, create output directory and set cron job to run ‘weekly.sh’ every Thu at 2:00 AM. 

 


File updates required 

Edit file /srv/tomcat/script/control/em-scripts/gen_scripts_data/guestos/guestos.py 

update with user and PW for said account 

TURBO_USER = '<user>' 
TURBO_PASS = '<password>' 

 

Edit file /srv/tomcat/script/control/em-scripts/gen_scripts_data/triad/triad_with_current_actions.py 

update with user and PW for said account 

TURBO_USER = 'administrator' 

TURBO_PASS = 'administrator' 

 

 

To use prep-system.sh and install python internet access is required.  Offline python install instructions here.  https://vmturbo.atlassian.net/wiki/spaces/~austin.portal/pages/174073109/Installing+the+Pro-Services+Integration+Environment 
