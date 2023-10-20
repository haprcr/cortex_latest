import sys
import yaml
import json

_CONFIG_FILE = "../../../config/config.json"
_CDC_SETTINGS_STANDARD_TEMPLATE = "cdc_settings_standard.yaml"
_TABLES_DATA = "../../../reporting.json"

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
    
    

def get_data():
    with open(_TABLES_DATA, 'r')  as dependency_data:
        dict_fa = json.load(dependency_data)
        return dict_fa

def get_list_tables(sqlFlavour, choice_list, dict_fa):
    cdc_list = []
    for i in choice_list:
        cdc_list = cdc_list + dict_fa[i]["cdc"][sqlFlavour]
    print("cdc_list:", cdc_list)
    return cdc_list


def generate_cdc_settings(choice_list):
    sqlFlavour = get_sql_flavour()
    dict_fa = get_data()
    cdc_tables_list = get_list_tables(sqlFlavour, choice_list, dict_fa)
    cdc_settings_data = get_list_cdc_settings(cdc_tables_list)
    write_to_new_cdc_settings("cdc_settings.yaml", cdc_settings_data)
    print("SUCCESS")


if __name__ == '__main__':
    choice_list_str = sys.argv[2:]
    print("choice_list_str", list(choice_list_str))
    generate_cdc_settings(choice_list_str)



