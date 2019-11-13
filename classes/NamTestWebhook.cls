@RestResource(urlMapping='/clickdeploy')
global without sharing class NamTestWebhook {
    @HttpGet
    global static String test() {
        return 'OK';
    }
    
	@HttpPost
	global static String save() {
		RestRequest request = RestContext.request; 
		String jSONRequestBody = request.requestBody.toString().trim();
        Session__c newSession = new Session__c(Description__c = jSONRequestBody, Level__c = 'Beginner', Session_Date__c = Datetime.now());
        insert newSession;
        return 'OK';
    }
}