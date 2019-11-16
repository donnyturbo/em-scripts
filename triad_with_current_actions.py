import vmtconnect as vc
import csv
import glob
from datetime import datetime


TURBO_TARGET = 'localhost'
TURBO_USER = 'administrator'
TURBO_PASS = 'administrator'
IN_FILE_NAME = glob.glob('/tmp/systemd*mariadb.service*/tmp/historical_triad.csv')[0]
OUT_FILE_NAME = './triad_with_outstanding_actions.csv'


def read_csv(csv_name):
    with open(csv_name, 'r', encoding='utf-8-sig') as csvfile:
        reader = csv.DictReader(csvfile)
        
        return [dict(row) for row in reader]


def get_action_details(actions):
    l = []

    for action in actions:

        try:
            l.append({'risk_uuid': action['risk']['uuid'],
                      'location': action['target']['environmentType']})

        except KeyError:
            pass

    return l


def get_notification_details(actions_details):
    risks = vmt.request('markets/Market/notifications/')
    l = []
    
    for risk in risks:
        for action in actions_details:
            d = {'risk_uuid': action['risk_uuid'],
                 'location': action['location']}

            if action['risk_uuid'] == risk['uuid']:
                d['entity_type'] = risk['shortDescription'].split('::')[0]
                d['category'] = risk['subCategory']
                d['risk_type'] = risk['shortDescription'].split('::')[-1]
                l.append(d)


    return l


def get_counts(actions_details):
    v = {}

    for action in actions_details:
        v.setdefault(action['entity_type'] + '::' 
                     + action['risk_type'] + '::'
                     + action['location'] + '::'
                     + action['category'], 0)
        
        v[(action['entity_type'] + '::' 
           + action['risk_type'] + '::'
           + action['location'] + '::'
           + action['category'])] += 1

    return [{'entity_type': key.split('::')[0],
             'risk_type': key.split('::')[1],
             'location': key.split('::')[2],
             'category': key.split('::')[3],
             'count': value} 
             for key, value in v.items()]


def combine_current_and_hist(cur_action, hist_actions):
    matched = []
    for cur_a in cur_action:
        for hist_a in hist_actions:
            if (hist_a['Entity Type'] == cur_a['entity_type'] and
                    hist_a['Risk Type'] == cur_a['risk_type'] and
                    hist_a['Location'] == cur_a['location'] and
                    hist_a['Category'] == cur_a['category']):
                    
                hist_a['Actions Outstanding'] = cur_a['count']
                    
                if datetime.strptime(hist_a['End Date'], '%Y-%m-%d') < datetime.today():
                    hist_a['End Date'] = datetime.strftime(datetime.today(),
                                                           '%Y-%m-%d')

                matched.append(cur_a)

    for action in cur_action:
        if action not in matched:
            hist_actions.append({'Start Date': datetime.strftime(datetime.today(),
                                                               '%Y-%m-%d'),
                               'End Date': datetime.strftime(datetime.today(),
                                                             '%Y-%m-%d'),
                               'Location': action['location'],
                               'Entity Type': action['entity_type'],
                               'Category': action['category'],
                               'Risk Type': action['risk_type'],
                               'Risks Avoided': 0,
                               'Actions Completed': 0,
                               'Actions Outstanding': action['count']})
    
    return hist_actions


def write_csv(final_report, dest_path):

    with open(dest_path, 'w') as csvfile:
        fieldnames = final_report[0].keys()
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames) 
        writer.writeheader()
        
        for i in final_report:    
            writer.writerow(i)


if __name__ == '__main__':
    vmt = vc.VMTConnection(TURBO_TARGET, TURBO_USER, TURBO_PASS)
    actions_list = vmt.request('markets/Market/actions/')
    action_details = get_notification_details(get_action_details(actions_list))
    total_counts = get_counts(action_details)
    hist_actions = read_csv(IN_FILE_NAME)
    final_report = combine_current_and_hist(total_counts, hist_actions)
    write_csv(final_report, OUT_FILE_NAME)
