#! /bin/bash
# Cleanup of generated files
rm -f $(ls -d /tmp/*maria*/tmp/|head -n 1)/*  
# Run all_Scripts and save within the output  
/srv/tomcat/script/control/em-scripts/all_scripts.sh  
# Change working directory to mariadb tmp  
cd $(ls -d /tmp/*maria*/tmp/|head -n 1)/  
# Zip output to /srv/tomcat/script/control/em-scripts/output/  
zip -r "/srv/tomcat/data/repos/output/Turbo-Weekly-$(date +"%Y-%m-%d").zip" *
