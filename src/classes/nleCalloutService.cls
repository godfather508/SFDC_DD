/**
* See https://github.com/financialforcedev/fflib-apex-common for more info
*
* Install library via
*   https://githubsfdeploy.herokuapp.com/app/githubdeploy/financialforcedev/fflib-apex-common
*/

/**
* Encapsulates all service layer logic for a given function or module in the application
* 
* For more guidelines and details see 
*   https://developer.salesforce.com/page/Apex_Enterprise_Patterns_-_Service_Layer
*
**/
public class nleCalloutService
{
    public static nleCalloutResult up_getToken(Nle_Org_Config__c orgConfig) {
        nleCalloutResult result = new nleCalloutResult('up_getToken');
        String base_URL = nleMetadataObjectConstant.SFDC_AUTH;
        base_URL += '/token?';
        base_URL += 'grant_type=password&';
        base_URL += '&client_id=' + EncodingUtil.urlEncode(orgConfig.Client_Id__c, 'UTF-8');
        base_URL += '&client_secret=' + EncodingUtil.urlEncode(orgConfig.Client_Secret__c, 'UTF-8');
        base_URL += '&username=' + EncodingUtil.urlEncode(orgConfig.Username__c, 'UTF-8');
        base_URL += '&password=' + EncodingUtil.urlEncode(orgConfig.Password__c, 'UTF-8');
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(base_URL);
        req.setMethod('POST');
        req.setTimeout(60000);
        Http http = new Http();

        system.debug('ConnectToOrg base_URL: ' + base_URL);
        
        try {
            string responseBody = '';
            HttpResponse res = http.send(req);
            responseBody = res.getBody();
            System.debug(responseBody);

            NleToken tokenObject = (NleToken)(JSON.deserialize(responseBody, NleToken.class));
            orgConfig.Environment_URL__c = tokenObject.instance_url;
            orgConfig.Access_Token__c = tokenObject.access_token;
            Integer sectionTimeout = orgConfig.Session_Timeout__c == null ? 120 : Integer.valueOf(orgConfig.Session_Timeout__c);
            orgConfig.Token_Expire_On__c = system.now().addMinutes(sectionTimeout).addSeconds(-1);
            
            if (res.getStatusCode() == 200) {
               result.hasError = false;   
            } else {
                result.hasError = true;
                result.error_message = tokenObject.error + '. ' + tokenObject.error_description;
            }
        } 
        catch (Exception ex) {
            result.hasError = true;
            result.error_message = ex.getMessage();
        }

        system.debug(result);
        
        return result;
    }

    
    public static nleCalloutResult getObjects(Nle_Org_Config__c orgConfig) {
        nleCalloutResult result = new nleCalloutResult('getObjects');

        nleCalloutResult connect = getConnect(orgConfig);
        if (connect.hasError) {
            return connect;
        }
        
        String base_URL = orgConfig.Environment_URL__c;
        base_URL += '/services/data/v37.0/';
        base_URL += 'sobjects';
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(base_URL);
        req.setHeader('Authorization', 'Bearer ' + orgConfig.Access_Token__c);
        req.setMethod('GET');
        req.setTimeout(60000);

        system.debug('getObjects base_URL: ' + base_URL);
        
        try {
            string responseBody = '';
            HttpResponse res = http.send(req);
            responseBody = res.getBody();
            System.debug(responseBody);
            
            nleCalloutJSONObjects objs = (nleCalloutJSONObjects)(JSON.deserialize(responseBody, nleCalloutJSONObjects.class));
            result.data = objs;

            if (res.getStatusCode() == 200) {
               result.hasError = false;
            } else {
                result.hasError = true;
                result.error_message = objs.error + '. ' + objs.error_description;
            }
        } 
        catch (Exception ex) {
            result.hasError = true;
            result.error_message = ex.getMessage();
        }

        system.debug('getObjects result:' + result);
        system.debug('getObjects data:' + result.data);
        
        return result;
    }

    public static nleCalloutResult getObject(Nle_Org_Config__c orgConfig, String objectName) {
        nleCalloutResult result = new nleCalloutResult('GetObject');
        
        nleCalloutResult connect = getConnect(orgConfig);
        if (connect.hasError) {
            return connect;
        }
        
        String base_URL = orgConfig.Environment_URL__c;
        base_URL += '/services/data/v37.0/sobjects/';
        base_URL += objectName;
        base_URL += '/describe';
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(base_URL);
        req.setHeader('Authorization', 'Bearer ' + orgConfig.Access_Token__c);
        req.setMethod('GET');
        req.setTimeout(60000);

        system.debug('getObject base_URL: ' + base_URL);
        
        try {
            string responseBody = '';
            HttpResponse res = http.send(req);
            responseBody = res.getBody();
            System.debug(responseBody);
            
            nleCalloutJSONObject objs = (nleCalloutJSONObject)(JSON.deserialize(responseBody, nleCalloutJSONObject.class));
            result.data = objs;

            if (res.getStatusCode() == 200) {
               result.hasError = false;
            } else {
                result.hasError = true;
                result.error_message = objs.error + '. ' + objs.error_description;
            }
        } 
        catch (Exception ex) {
            result.hasError = true;
            result.error_message = ex.getMessage();
        }

        system.debug('getObject result:' + result);
        system.debug('getObject data:' + result.data);
        
        return result;
    }
    
    /**************************** Private methods ****************************/ 
    private static nleCalloutResult getConnect(Nle_Org_Config__c orgConfig) {
        nleCalloutResult result = new nleCalloutResult('getConnect');

        if (String.isEmpty(orgConfig.Access_Token__c)) {
            result.hasError = true;
            result.error_message = 'Connection issue. Plz try re-connect!';
        }

        if (orgConfig.Token_Expire_On__c < system.now()) {//up_getToken
            if (orgConfig.RecordType.Name == nleMetadataObjectConstant.UA_FLOW 
                && String.isNotEmpty(orgConfig.Client_Id__c)) {
                result = ua_refreshToken(orgConfig);
            } else if (orgConfig.RecordType.Name == nleMetadataObjectConstant.UP_FLOW 
                && String.isNotEmpty(orgConfig.Client_Id__c)
                && String.isNotEmpty(orgConfig.Client_Secret__c)
                && String.isNotEmpty(orgConfig.Username__c)
                && String.isNotEmpty(orgConfig.Password__c)) {
                result = up_getToken(orgConfig);
            }
        }

        return result;
    }

    /******* RefreshToken For User-Agent OAuth Authentication Flow Implementation *********/ 
    private static nleCalloutResult ua_refreshToken(Nle_Org_Config__c orgConfig) {
        nleCalloutResult result = new nleCalloutResult('refreshToken');

        if (orgConfig == null || String.isEmpty(orgConfig.Access_Token__c)) {
            result.hasError = true;
            result.error_message = 'RefreshToken. Org Config issue';
            return result;
        }

        if (orgConfig.Token_Expire_On__c >= system.now()) {
            return result;
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        String base_URL = nleMetadataObjectConstant.SFDC_AUTH;
        base_URL += '/grant_type=refresh_token';
        base_URL += '/grant_type=refresh_token';
        base_URL += '&refresh_token=' + EncodingUtil.urlEncode(orgConfig.Access_Token__c, 'UTF-8');
        base_URL += '&client_id=' + EncodingUtil.urlEncode(orgConfig.Client_Id__c, 'UTF-8');
        base_URL += '&client_secret=' + EncodingUtil.urlEncode(orgConfig.Client_Secret__c, 'UTF-8');
        
        req.setEndpoint(base_URL);
        req.setMethod('POST');
        req.setTimeout(60000);
        
        system.debug('refreshToken base_URL: ' + base_URL);
        
        try {
            string responseBody = '';
            HttpResponse res = http.send(req);
            responseBody = res.getBody();
            System.debug(responseBody);

            NleToken tokenObject = (NleToken)(JSON.deserialize(responseBody, NleToken.class));
            result.data = tokenObject;
            
            if (res.getStatusCode() == 200) {
               result.hasError = false;   
            } else {
                result.hasError = true;
                result.error_message = tokenObject.error + '. ' + tokenObject.error_description;
            }
        } 
        catch (Exception ex) {
            result.hasError = true;
            result.error_message = ex.getMessage();
        }

        system.debug(result);
        
        return result;
    }
}