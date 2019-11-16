# Python 3.6 install
chown -R tomcat:tomcat /srv/tomcat/script/control/em-scripts/
yum -y install yum-utils
yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yum -y install python36u python36u-libs python36u-setuptools python36u-pip
cd /usr/bin && ln -s python3.6 python3 && ln -s pip3.6 pip3
pip3 install requests
# dir creation
mkdir /srv/tomcat/data/repos/output
# update crontab
#backup current crontab
crontab -l > crontab.bkup
#echo new cron into cron file
#crontab -l > /tmp/ctab.bkp && echo "00 02   thu sh /srv/tomcat/script/control/em-scripts/weekly.sh" >> /tmp/ctab.bkp && crontab /tmp/ctab.bkp && rm /tmp/ctab.bkp -f
echo "00 02   thu sh /srv/tomcat/script/control/em-scripts/weekly.sh" >> crontab -u root
