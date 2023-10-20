import sys
import yaml
import json
import argparse

_CONFIG_FILE = "../../../config/config.json"
_CDC_SETTINGS_STANDARD_TEMPLATE = "cdc_settings_standard.yaml"
_TABLES_DATA = "../../../tables_data.json"

def get_sql_flavour():
    with open(_CONFIG_FILE) as settings_file:
            data = json.load(settings_file)
            sqlFlavour = data['SAP']['SQLFlavor']
            return sqlFlavour


def get_list_cdc_settings(table_list):
    try:
        with open(_CDC_SETTINGS_STANDARD_TEMPLATE, 'r') as yaml_content:
                yaml_content = yaml_content.read()
                parsed_yaml = yaml.safe_load(yaml_content)
                data_to_replicate = parsed_yaml['data_to_replicate']

                data_updated = {"data_to_replicate":[]}
                for entry in data_to_replicate:
                        if entry['base_table']  in table_list:
                            data_updated["data_to_replicate"].append(entry)
        return data_updated
    except IOError as e:
        print("Following exception encountered: ", e)
    



def write_to_new_cdc_settings(cdc_settings_new, data):
    """Generates CDC Settings file from template."""
    with open('cdc_settings.yaml', 'w') as cdc_settings_new:
            yaml.dump(data, cdc_settings_new, sort_keys=False)
            print(f'Created CDC Settings file {cdc_settings_new}')
    
    
    
def get_index(choice_list):
    indicies = [str(idx+1) for idx, ele in enumerate(choice_list) if ele == "1"]
    # print("indicies: ", indicies)
    return indicies


def get_data():
    with open(_TABLES_DATA, 'r')  as dependency_data:
        dict_fa = json.load(dependency_data)
        return dict_fa
    

tables_list = []
def generate_cdc_settings(choice_list):
    sqlFlavour = get_sql_flavour()
    dict_fa = get_data()
    if "0" not in choice_list:
        print("Deploying cdc tables for all the Functional area")
        tables_list = dict_fa["cdc"]["1"][sqlFlavour] + dict_fa["cdc"]["2"][sqlFlavour] + dict_fa["cdc"]["3"][sqlFlavour]
        tables_list = list(set(tables_list))
        # print(tables_list)
    else:
        idxes = get_index(choice_list)
        if len(idxes) ==2:
            tables_list = list(set(dict_fa["cdc"][idxes[0]][sqlFlavour] + dict_fa["cdc"][idxes[1]][sqlFlavour]))
        else:
            tables_list = dict_fa["cdc"][idxes[0]][sqlFlavour]
    print("tables_list: ", tables_list)
    cdc_settings_data = get_list_cdc_settings(tables_list)
    write_to_new_cdc_settings("cdc_settings.yaml", cdc_settings_data)
    print("SUCCESS")

# [1, 0, 1]
if __name__ == '__main__':
    choice_list_str = sys.argv[2:]
    print("choice_list_str", list(choice_list_str))
    # Convert the elements of the list to integers if needed (assuming they represent choices)
    # choice_list = [int(choice) for choice in choice_list]

    # Now, you have the choice_list as a Python list that you can use in your script
    # print(choice_list)
    # args = get_args()
    # print(args)
    # print("CHOICE_LIST:", args.choice_list)
    generate_cdc_settings(choice_list_str)



