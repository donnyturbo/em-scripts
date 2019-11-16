import requests
import csv
import json
import glob

in_file_name = glob.glob('/tmp/system*maria*/tmp/clus-host-vm.csv')[0]
out_file_name = './clus-host-vm-os.csv'
vm_server = 'localhost'
vmt_usr = 'administrator'
vmt_pwd = 'Turbonomics1234'
base_url = '/vmturbo/rest'

requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)


# Function to read CSV and convert to Python Dict

def csv_reader(filename):
    uuid_list = []
    csv_dict = []
    with open(filename, 'r') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            uuid_list.append(row['Guest OS'])
            csv_dict.append(dict(row))
    return uuid_list, csv_dict

# Loop through uuid_list to create dict with [key:value] = [uuid:guest_os] using API call

def find_guest_os(uuid_list):
    os_dict = {}
    for uuid in uuid_list:
        print(uuid)
        r = requests.get('https://' + vm_server + base_url + '/entities/' + uuid + '?include_aspects=true', auth=(vmt_usr, vmt_pwd),verify=False)
        response = r.json()
        for attribute in response:
            if 'aspects' in attribute:
                for aspects in response['aspects']:
                    for vm_aspect in response['aspects']['virtualMachineAspect']:
                        if vm_aspect == 'os':
                            os_dict[uuid] = response['aspects']['virtualMachineAspect']['os']
                            break
                        else:
                            os_dict[uuid] = 'No OS Found'    
    return os_dict


# Parse through csv_dict to combine with the os_dict values

def combine_os_dict_with_csv_dict(os_dict,csv_dict):
    for entity in csv_dict:
        for uuid in os_dict.keys():
            if entity['Guest OS'] == uuid:
                entity['Guest OS'] = os_dict[uuid]
    return csv_dict

# Create new output csv with updated dictionary

def csv_writer(final_list, dest_path):
    with open(dest_path, 'w') as csvfile:
        fieldnames = final_list[0].keys()
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames) 
        writer.writeheader()
        for i in final_list:    
            writer.writerow(i)  

def main(filename):
    uuid_list, csv_dict = csv_reader(filename)
    os_dict = find_guest_os(uuid_list)
    final_list = combine_os_dict_with_csv_dict(os_dict,csv_dict)
    csv_writer(final_list, out_file_name)

main(in_file_name)
