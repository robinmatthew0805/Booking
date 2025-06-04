@isTest
public class MockEmailTemplates implements HttpCalloutMock {
    
    public static void mockTemplateIds() {
        // Create a mock for Messaging.SingleEmailMessage
        Test.setMock(HttpCalloutMock.class, new MockEmailTemplates());
    }
    
    public HTTPResponse respond(HTTPRequest req) {
        // Create a fake HTTP response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"success":true}');
        res.setStatusCode(200);
        return res;
    }
    
    // Method to bypass email sending in tests
    public static Boolean isTestRunning = false;
    
    public static void startTest() {
        isTestRunning = true;
    }
    
    public static void stopTest() {
        isTestRunning = false;
    }
}