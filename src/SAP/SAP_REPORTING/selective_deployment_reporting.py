import sys
import json
import yaml


class selective_deployment():
    def __init__(self, choice_list, level, util, structure) -> None:
        self.utils = util
        self.choice_list = choice_list
        self.ecc_reporting = "reporting_settings_ecc_standard.yaml"
        self.structure = structure
        self.level = level
        if self.level == "data_model_deployment":
            self.generate_data_models_reporting()
        elif self.level == "functional_area_deployment":
            self.generate_functional_area_reporting()
        super().__init__()
        
    def generate_functional_area_reporting(self):
        sqlFlavour = self.utils.get_sql_flavour()
        functional_module_mapping = self.utils.get_func_modules_mapping()
        objects = self.structure.file_structure
        reporting_settings_file = 'reporting_settings_ecc_standard.yaml' if sqlFlavour.lower() == 'ecc' else 'reporting_settings_s4_standard.yaml'
        bq_independent_objects, bq_dependent_objects = self.utils.get_standard_reporting_settings(reporting_settings_file)

        if "0" not in self.choice_list:
            reporting_tables_list = functional_module_mapping["reporting"]["1"] + functional_module_mapping["reporting"]["2"] + functional_module_mapping["reporting"]["3"]
            reporting_tables_list = list(set(reporting_tables_list))
        else:
            idxes = self.utils.get_index(choice_list)
            if len(idxes) == 2:
                reporting_tables_list = list(set(functional_module_mapping["reporting"][idxes[0]] + functional_module_mapping["reporting"][idxes[1]]))
            else:
                reporting_tables_list = functional_module_mapping["reporting"][idxes[0]]
                
        objects_entry =self.utils.get_objects(bq_independent_objects, bq_dependent_objects, objects, reporting_tables_list)

        self.utils.write_to_new_reporting_settings(sqlFlavour, objects_entry)
        
        
    def generate_data_models_reporting(self):
        sqlFlavour = self.utils.get_sql_flavour()
        data_model_mapping = self.utils.get_data_model_mapping()
        objects = self.structure.file_structure
        reporting_settings_file = 'reporting_settings_ecc_standard.yaml' if sqlFlavour.lower() == 'ecc' else 'reporting_settings_s4_standard.yaml'
        bq_independent_objects, bq_dependent_objects = self.utils.get_standard_reporting_settings(reporting_settings_file)
        reporting_tables_list = self.utils.get_req_reporting_tables(self.choice_list, data_model_mapping)
        objects_entry =self.utils.get_objects(bq_independent_objects, bq_dependent_objects, objects, reporting_tables_list)

        self.utils.write_to_new_reporting_settings(sqlFlavour, objects_entry)

class structure():
    def __init__(self) -> None:
        self.file_structure = {
                            'bq_independent_objects':[], 
                            'bq_dependent_objects':[]
                        }
        super().__init__()


class utils():
    def __init__(self) -> None:
        self.config_file = "../../../config/config.json"
        self.data_model_mapping = "../../../data_models.json"
        self.functional_area_mapping = "../../../functional_modules.json"
        super().__init__()

    def get_sql_flavour(self):
        with open(self.config_file) as config_file:
            data = json.load(config_file)
            sqlFlavour = data['SAP']['SQLFlavor']
        return sqlFlavour

    def get_data_model_mapping(self):
        with open(self.data_model_mapping, 'r')  as dependency_data:
            data = json.load(dependency_data)
        return data

    def get_func_modules_mapping(self):
        with open(self.functional_area_mapping, 'r')  as dependency_data:
            data = json.load(dependency_data)
        return data

    def get_standard_reporting_settings(self, reporting_settings_file):
        with open(reporting_settings_file, 'r') as yaml_content:
            yaml_content = yaml_content.read()
            parsed_yaml = yaml.safe_load(yaml_content)
            bq_independent_objects = parsed_yaml['bq_independent_objects']
            bq_dependent_objects = parsed_yaml['bq_dependent_objects']
        return bq_independent_objects, bq_dependent_objects

    def get_req_reporting_tables(self, choice_list, mapping):
        reporting_list = []
        for i in choice_list:
            reporting_list = reporting_list + mapping[i]["reporting"]
        return reporting_list

    def get_objects(self, bq_independent_objects, bq_dependent_objects, sql_file, tables_list):
        for i in bq_independent_objects:
            if i['sql_file'].split('.')[0] in tables_list:
                sql_file['bq_independent_objects'].append(i)

                    
        for i in bq_dependent_objects:
            if i['sql_file'].split('.')[0] in  tables_list:
                    sql_file['bq_dependent_objects'].append(i)

        return sql_file

    
    def write_to_new_reporting_settings(self, sqlFlavour, reporting_data_required):
        reporting_settings_file = 'reporting_settings_ecc.yaml' if sqlFlavour.lower() == 'ecc' else 'reporting_settings_s4.yaml'

        with open(reporting_settings_file, 'w') as target:
            yaml.dump(reporting_data_required, target, sort_keys=False)


    def get_index(self, choice_list):
        indicies = [str(idx+1) for idx, ele in enumerate(choice_list) if ele == "1"]
        return indicies

if __name__ == '__main__':
    arguments = sys.argv[1:]
    choice_list = arguments[:-1]
    level = arguments[-1]

    selective_deployment(choice_list, level, utils(), structure())
    


