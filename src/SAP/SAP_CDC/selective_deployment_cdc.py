import sys
import json
import yaml


class selective_deployment():
    def __init__(self, choice_list, level, util) -> None:
        self.utils = util
        self.choice_list = choice_list
        self.file = "cdc_settings.yaml"
        self.level = level
        if self.level == "data_model_deployment":
            self.generate_data_models_cdc()
        elif self.level == "functional_area_deployment":
            self.generate_functional_area_cdc()
        
    def generate_functional_area_cdc(self):
        sqlFlavour = self.utils.get_sql_flavour()
        func_modules_mapping = self.utils.get_func_modules_mapping()
        if "0" not in self.choice_list:
            cdc_tables_list = func_modules_mapping["cdc"]["1"][sqlFlavour] + func_modules_mapping["cdc"]["2"][sqlFlavour] + func_modules_mapping["cdc"]["3"][sqlFlavour]
            cdc_tables_list = list(set(cdc_tables_list))
        else:
            idxes = self.utils.get_index(self.choice_list)
            if len(idxes) == 2:
                cdc_tables_list = list(set(func_modules_mapping["cdc"][idxes[0]][sqlFlavour] + func_modules_mapping["cdc"][idxes[1]][sqlFlavour]))
            elif len(idxes) == 1:
                cdc_tables_list = func_modules_mapping["cdc"][idxes[0]][sqlFlavour]
            else:
                print("You choose no to perform Selective Deployment")
                return 
        cdc_settings_data = self.utils.get_list_cdc_settings(cdc_tables_list)
        self.utils.write_to_new_cdc_settings(self.file, cdc_settings_data)


    def generate_data_models_cdc(self):
        sqlFlavour = self.utils.get_sql_flavour()
        data_model_mapping = self.utils.get_data_model_mapping()
        cdc_tables = self.utils.get_list_tables(sqlFlavour, self.choice_list, data_model_mapping)
        cdc_settings_new = self.utils.get_list_cdc_settings(cdc_tables)
        self.utils.write_to_new_cdc_settings(self.file, cdc_settings_new)


class utils():
    def __init__(self) -> None:
        self.config_file = "../../../config/config.json"
        self.cdc_settings_standard_template = "cdc_settings_standard.yaml"
        self.data_model_mapping = "../../../data_models.json"
        self.functional_area_mapping = "../../../functional_modules.json"

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

    def get_list_tables(self, sqlFlavour, choice_list, data_mapping):
        cdc_list = []
        for i in choice_list:
            cdc_list = cdc_list + data_mapping[i]["cdc"][sqlFlavour]
        return cdc_list

    def get_list_cdc_settings(self, cdc_tables_list):
        try:
            with open(self.cdc_settings_standard_template, "r") as cdc_settings_data:
                cdc_data = cdc_settings_data.read()
                parsed_yaml = yaml.safe_load(cdc_data)
                data_to_replicate = parsed_yaml['data_to_replicate']

                cdc_required = {"data_to_replicate":[]}
                for entry in data_to_replicate:
                        if entry['base_table']  in cdc_tables_list:
                            cdc_required["data_to_replicate"].append(entry)
                return cdc_required
        except IOError as e:
                print("Following exception encountered: ", e)


    def write_to_new_cdc_settings(self, file, cdc_data_required):
        try:
            with open(file, "w") as cdc_settings_new:
                yaml.dump(cdc_data_required, cdc_settings_new, sort_keys=False)
            
        except Exception as e:
            print("Error while writing to the YAML file:", e)


    def get_index(self, choice_list):
        indicies = [str(idx+1) for idx, ele in enumerate(choice_list) if ele == "1"]
        return indicies

if __name__ == '__main__':
    # parser = argparse.ArgumentParser(
    #     description=__doc__,
    #     formatter_class=argparse.RawDescriptionHelpFormatter,
    # )

    # parser.add_argument("inventory")
    # parser.add_argument("finance")
    # parser.add_argument("o2c")
    # parser.add_argument("type", str)
    # args = parser.parse_args()

    arguments = sys.argv[1:]
    choice_list = arguments[:-1]
    level = arguments[-1]

    if level == "functional_area_deployment":
        if "1" not in choice_list:
            print("You have not selected any options, hence exiting the Selective Deployment for Functional Area")
            exit(1)

    selective_deployment(choice_list, level, utils())
    


