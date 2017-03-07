public class nleMetadataObjectsController {
    private Map<String, Nle_Org_Config__c> orgConfigs;
    private List<SelectOption> orgConfigSelectOptions;
    private Nle_Org_Config__c currentOrgConfig;
    private List<nleCalloutJSONObject> jObjectDetails {get;set;}
    
    public List<JObject> jObjects {get;set;}
    public Set<String> currentSelectedObjects {get;set;}
    public List<Account> accountList{get;set;}
    public List<Contact> contactList{get;set;}
    //public String achorElement {get;set;}
    
    public boolean isConnected {get;set;}
    public Integer noOfOrgConfigs {get;set;}
    public Id currentOrgConfigId {get;set;}
    
    public String xlsHeader {
        get {
            String strHeader = '';
            strHeader += '<?xml version="1.0"?>';
            strHeader += '<?mso-application progid="Excel.Sheet"?>';
            return strHeader;
        }
    }

    public PageReference methodOne() {
        return null;
    }
    
    public nleMetadataObjectsController() {
        System.debug('nleMetadataObjectsController');
        //System.debug('achorElement: ' + getAchorElement());
        System.debug('apexPages.currentPage: ' + ApexPages.currentPage());
        System.debug('apexPages.currentPage.getHeaders: ' + ApexPages.currentPage().getHeaders());
        
        PageReference currentPage = ApexPages.currentPage();
        String currentUrl = currentPage.getUrl();
        String orgConfigIdStr = currentPage.getParameters().get('state');
        System.debug('orgConfigIdStr: ' + orgConfigIdStr);
        System.debug('currentUrl: ' + currentUrl);
        System.debug('getAnchor: ' + currentPage.getAnchor());
        
        if (currentUrl.indexOf('nleMetadataObjects') == -1) {
            if (String.isNotEmpty(orgConfigIdStr)) {
                initialExport(orgConfigIdStr);
            }
        } else {
            String mode = currentPage.getParameters().get('mode');
            System.debug('mode: ' + mode);
            if (String.isNotEmpty(mode) && mode == 'token' 
                && String.isNotEmpty(orgConfigIdStr)) {
                    String access_token = currentPage.getParameters().get('access_token');
                    String instance_url = currentPage.getParameters().get('instance_url');
                    System.debug('access_token: ' + access_token);
                    System.debug('instance_url: ' + instance_url);
                } else {
                    initialPageObjects();
                }
        }	
    }
    
    public pageReference changeOrgConfig() {
        if (orgConfigs != null) {
            currentOrgConfig = orgConfigs.get(currentOrgConfigId);
            if (currentOrgConfig != null) {
                if (String.isNotEmpty(currentOrgConfig.Selected_Objects__c)) {
                    List<String> temp = currentOrgConfig.Selected_Objects__c.split('; ');
                    currentSelectedObjects.clear();
                    currentSelectedObjects.addAll(temp);
                }
                
                if (String.isNotEmpty(currentOrgConfig.Access_Token__c)) {
                    this.isConnected = true;
                    getObjects();
                } else {
                    this.isConnected = false;
                }                
            }
        }
        return null;
    }
    
    public PageReference refreshObjects() {
        getObjects();
        return null;
    }
    
    public PageReference exportDD() {
        System.debug('exportDD');
        if (this.currentOrgConfig != null && String.isNotEmpty(this.currentOrgConfig.Selected_Objects__c)) {
            String base_URL = '/apex/ExportDetailDesign?state=' + this.currentOrgConfig.Id;
            System.debug('base_URL: ' + base_URL);
            return new Pagereference(base_URL);
        }
        
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Org issue.'));
        return null;
    }
    
    public PageReference newConfig() {
        Schema.DescribeSObjectResult r = Nle_Org_Config__c.sObjectType.getDescribe();
        String keyPrefix = r.getKeyPrefix();
        return new Pagereference('/' + keyPrefix + '/e?retURL=/apex/nleMetadataObjects&saveURL=/apex/nleMetadataObjects');
    }
    
    public pageReference connectToOrg() {
        if (currentOrgConfig.RecordType.Name == nleMetadataObjectConstant.UA_FLOW && String.isNotEmpty(currentOrgConfig.Client_Id__c)) {
            String base_URL = nleMetadataObjectConstant.SFDC_AUTH;
            base_URL += '/authorize?response_type=token';
            base_URL += '&client_id=' + currentOrgConfig.Client_Id__c;
            base_URL += '&redirect_uri=https://' + ApexPages.currentPage().getHeaders().get('Host') + '/apex/nleMetadataObjects';
            base_URL += '&state=' + currentOrgConfig.Id;
            return new Pagereference(base_URL);
        } else if (currentOrgConfig.RecordType.Name == nleMetadataObjectConstant.UP_FLOW 
                   && String.isNotEmpty(currentOrgConfig.Client_Id__c)
                   && String.isNotEmpty(currentOrgConfig.Client_Secret__c)
                   && String.isNotEmpty(currentOrgConfig.Username__c)
                   && String.isNotEmpty(currentOrgConfig.Password__c)) {
                       nleCalloutResult result = nleCalloutService.up_getToken(currentOrgConfig);
                       if (!result.hasError) {
                           this.isConnected = true;
                           
                           getObjects();
                       } else {
                           this.isConnected = false;
                           ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, result.status + '. ' + result.error_message));
                       }
                       return null;
                   }
        
        this.isConnected = false;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please check org config!'));
        return null;
    }
    
    public pageReference revokeToOrg() {
        if (currentOrgConfig != null) {
            currentOrgConfig.Access_Token__c = null;
            UPDATE currentOrgConfig;
            
            this.isConnected = false;
        }
        
        return null;
    }
    
    public pageReference saveSelectedObjects() {
        this.currentSelectedObjects.clear();
        for (JObject jObject : jObjects) {
            if (jObject.selected == true) {
                this.currentSelectedObjects.add(jObject.objectNameAPI);
            }
        }
        if (this.currentOrgConfig != null) {
            List<String> tem = new List<String>();
            tem.addAll(this.currentSelectedObjects);
            this.currentOrgConfig.Selected_Objects__c = String.join(tem,'; ');
            UPDATE this.currentOrgConfig;
            
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'The config is saved'));
        }
        return null;    
    }
    
    /**************************** Getters methods ****************************/ 
    public List<SelectOption> getOrgConfigSelectOptions() {
        return this.orgConfigSelectOptions;
    }
    
    public List<nleCalloutJSONObject> getJObjectDetails() {
        this.jObjectDetails = new List<nleCalloutJSONObject>();
        if (currentOrgConfig!= null && string.isNotEmpty(currentOrgConfig.Selected_Objects__c)) {
            List<String> objectNames = currentOrgConfig.Selected_Objects__c.split('; ');
            for (String objectName : objectNames) {
                nleCalloutResult result = nleCalloutService.getObject(this.currentOrgConfig, objectName);
                if (!result.hasError) {
                    System.debug('result.data: ' + result.data);
                    jObjectDetails.add((nleCalloutJSONObject) result.data);
                }
            }
        }
        
        return this.jObjectDetails;
    }
    
    /**************************** Private methods ****************************/ 
    private void initialExport(String orgConfigIdStr) {
        System.debug('initialExport');
        Id orgConfigId = Id.valueOf(orgConfigIdStr);
        if (orgConfigId.getSobjectType() == Nle_Org_Config__c.SobjectType) {
            this.currentOrgConfig = [SELECT Id, Name, Client_Id__c, Client_Secret__c, Username__c, Password__c, Redirect_URL__c,
                                     Access_Token__c, Token_Expire_On__c, Environment_URL__c, Selected_Objects__c, RecordType.Name
                                     FROM Nle_Org_Config__c WHERE Id = :orgConfigId LIMIT 1];
        }
    }
    
    private void initialPageObjects() {
        isConnected = false;
        currentSelectedObjects = new Set<String>();
        
        orgConfigs = new Map<String, Nle_Org_Config__c>([SELECT Id, Name, Client_Id__c, Client_Secret__c, Username__c, Password__c, Redirect_URL__c,
                                                         Access_Token__c, Token_Expire_On__c, Environment_URL__c, Selected_Objects__c, RecordType.Name
                                                         FROM Nle_Org_Config__c ORDER BY CreatedDate]);
        
        noOfOrgConfigs = orgConfigs.size();
        
        this.orgConfigSelectOptions = new List<SelectOption>();
        this.orgConfigSelectOptions.add(new SelectOption('', 'None'));
        for (Nle_Org_Config__c orgConfig : orgConfigs.values()) {
            this.orgConfigSelectOptions.add(new SelectOption(orgConfig.id, orgConfig.Name));
        }
    }
    
    private Boolean getObjects() {
        system.debug('getObjects isConnected: ' + isConnected);
        system.debug('getObjects currentOrgConfig: ' + currentOrgConfig);
        
        if (this.currentOrgConfig == null || !this.isConnected) {
            return false;
        }
        
        nleCalloutResult result = nleCalloutService.getObjects(this.currentOrgConfig);
        this.jObjects = new List<JObject>();
        if (!result.hasError) {
            nleCalloutJSONObjects data = (nleCalloutJSONObjects) result.data;
            if (data != null) {
                for (nleCalloutJSONObjects.JSONObjects obj : data.sobjects) {
                    this.jObjects.add(new JObject(obj, this.currentSelectedObjects));
                }
            }
            
            UPDATE currentOrgConfig;
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, result.status + '. ' + result.error_message));
            return false;
        }
        
        return true;
    }
    
    /**************************** wapper class ****************************/ 
    public class JObject {
        public Boolean selected{get; set;}
        public String objectNameAPI{get; set;}
        public String objectLabel{get; set;}
        
        public JObject(nleCalloutJSONObjects.JSONObjects obj, Set<String> currentSelectedObjects) {
            objectNameAPI = obj.name;
            objectLabel = obj.label + ' (' + obj.name + ')';
            
            if (currentSelectedObjects != null && currentSelectedObjects.contains(obj.name)) {
                selected = true;
            } else {
                selected = false;
            }
        }
    }
}