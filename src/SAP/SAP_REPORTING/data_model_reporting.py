import sys
import yaml
import json

_CONFIG_FILE = "../../../config/config.json"
_TABLES_DATA = "../../../reporting.json"

def get_sql_flavor():
    with open(_CONFIG_FILE) as settings_file:
            data = json.load(settings_file)
            sqlFlavour = data['SAP']['SQLFlavor']
    return sqlFlavour

def get_standard_reporting_settings(reporting_settings_file):
    with open(reporting_settings_file, 'r') as yaml_content:
            yaml_content = yaml_content.read()
            parsed_yaml = yaml.safe_load(yaml_content)
            bq_independent_objects = parsed_yaml['bq_independent_objects']
            bq_dependent_objects = parsed_yaml['bq_dependent_objects']
    return bq_independent_objects, bq_dependent_objects

def get_data():
    with open(_TABLES_DATA, 'r')  as dependency_data:
        dict_fa = json.load(dependency_data)
        return dict_fa



def write_to_new_reporting_settings(reporting_settings_file_new, settings_data):
    with open(reporting_settings_file_new, 'w') as target:
            yaml.dump(settings_data, target, sort_keys=False)
    
def get_reporting_tables(dict_fa, choice_list):
    reporting_list = []
    for i in choice_list:
        reporting_list = reporting_list + dict_fa[i]["reporting"]
    print("reporting_list:", reporting_list)
    return reporting_list

def generate_reporting_settings(choice_list):
    sqlFlavour = get_sql_flavor()
    dict_fa = get_data()
    sql_file = {
        'bq_independent_objects':[], 
        'bq_dependent_objects':[]
    }
    reporting_settings_file = 'reporting_settings_ecc_standard.yaml' if sqlFlavour.lower() == 'ecc' else 'reporting_settings_s4_standard.yaml'
    bq_independent_objects, bq_dependent_objects = get_standard_reporting_settings(reporting_settings_file)
    # print(bq_independent_objects, bq_dependent_objects)
    
    tables_list = get_reporting_tables(dict_fa, choice_list)


    # print("tables_list:", tables_list)
    for i in bq_independent_objects:
        if i['sql_file'].split('.')[0] in tables_list:
                sql_file['bq_independent_objects'].append(i)

                    
    for i in bq_dependent_objects:
        if i['sql_file'].split('.')[0] in  tables_list:
                sql_file['bq_dependent_objects'].append(i)
    # print(sql_file)
    reporting_settings_file_new = 'reporting_settings_ecc.yaml' if sqlFlavour.lower() == 'ecc' else 'reporting_settings_s4.yaml'
    write_to_new_reporting_settings(reporting_settings_file_new, sql_file)
    


if __name__ == "__main__":
    choice_list_str = sys.argv[2:]
    print("choice_list_str", list(choice_list_str))
    generate_reporting_settings(choice_list_str)
