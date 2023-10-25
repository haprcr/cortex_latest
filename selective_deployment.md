## Selective Deployment For Cortex Framework

The **Selective Deployment** feature allows you to deploy the Cortex Framework selectively at both the Functional Area and Data Model levels, providing flexibility and customization.

With Selective Deployment, you have the ability to tailor your Cortex Framework deployment to suit your business needs, focusing on specific areas or data models that are most relevant to your operations.

Whether you require a comprehensive deployment across all modules or a more targeted approach, the Selective Deployment for Cortex Framework offers the flexibility and scalability to accommodate your specific use case.

Make the most of Selective Deployment to streamline your deployment process and optimize the Cortex Framework to meet your unique business requirements.


### Functional Area Deployment

At the Functional Area level, you can choose to deploy one or more of the following modules based on your specific requirements:

1. **Inventory or Supply Chain**
2. **Order to Cash**
3. **Finance**

### Data Model Deployment

For finer-grained control, you can opt to deploy specific Data Models from the list below:

1. **AccountingDocumentsReceivable**
2. **currency_conversion**
3. **CurrencyConversion**
4. **currency_decimal**
5. **AccountsPayable**
6. **AccountsPayableTurnover**
7. **DaysPayableOutstanding**
8. **CashDiscountUtilization**
9. **VendorPerformance**
10. **MaterialLedger**
11. **Languages_T002**
12. **InventoryByPlant**
13. **InventoryKeyMetrics**
14. **SalesOrders_V2**
15. **Deliveries**
16. **Billing**
17. **MaterialsMD**
18. **CustomersMD**
19. **CountriesMD**
20. **SalesOrganizationsMD**
21. **DistributionChannelsMD**
22. **SalesOrderPricing**
23. **OneTouchOrder**
24. **SalesOrderScheduleLine**
25. **DivisionsMD**
26. **SalesOrderHeaderStatus**
27. **SalesOrderPartnerFunction**


### Deployment Steps

Here's the content formatted into a README-compatible layout:

---

## Deployment Steps

### Setting Up Configuration Files

To ensure that the required configuration and script files are correctly placed in their respective folders for effective use of the Cortex Framework's Selective Deployment feature, follow these steps:

1. Execute the `copy_files.sh` script to copy the necessary files. Ensure the script is executable by running the following command:
   
   ```bash
   chmod +x copy_files.sh
   ```

   The `copy_files.sh` script performs the following tasks:

   - **Copy Files to CDC Folder:**
     - Copy the file `cdc_settings_standard.yaml` and `selective_deployment_cdc.py` into the `src/SAP/SAP_CDC/` folder.

   - **Copy File to Reporting Config Folder:**
     - Copy the file `reporting_settings_local_k9_standard.yaml` into the `src/SAP/SAP_REPORTING/config/` folder.

   - **Copy Files to Reporting Folder:**
     - Copy the following files to the `src/SAP/SAP_REPORTING/` folder:
       - `reporting_settings_ecc_standard.yaml`
       - `reporting_settings_s4_standard.yaml`
       - `selective_deployment_reporting.py`

   - **Copy Files to the Main Folder:**
     - Copy the following files to the `cortex-data-foundation/` folder:
       - `data_models.json`
       - `functional_modules.json`
       - `selective_deploy.sh`

These steps will ensure that the required configuration and script files are correctly placed in the respective folders, enabling you to use the Selective Deployment feature of the Cortex Framework effectively.

--------

## Performing Selective Deployment

After completing the initial setup, you can proceed to perform Selective Deployment using the Cortex Framework. Below are the steps for deploying Functional Areas and Data Models:

### Functional Area Deployment

1. Make the `selective_deploy.sh` script executable by running the following command:

   ```bash
   chmod +x selective_deploy.sh
   ```
   
2. Execute the `selective_deploy.sh` script.

3. When prompted, choose option 4 for Cortex Selective Deployment.

4. Select option 2 for Functional Area(s) Deployment.

5. Type "Y" to confirm your intent to perform Selective Deployment for Functional Areas.

6. Enter either 0 or 1 to proceed as per your selection.

### Data Models Deployment

1. Execute the `selective_deploy.sh` script.

2. When prompted, choose option 3 for Data Models Deployment.

3. Enter a range or options associated with the data models that you would like to deploy.

4. Press Enter to confirm your selection.

5. Execute the `main_deploy.sh` file to initiate the deployment based on the input received.

By following these steps, you can perform Selective Deployment of the Cortex Framework for both Functional Areas and Data Models.
