public with sharing class PayPalService {
    
    // PayPal API configuration
    private static final String SANDBOX_BASE_URL = 'https://api-m.sandbox.paypal.com';
    private static final String CLIENT_ID = 'Acl0m4WvI6mdl_arvf-XpKL9baFlPR8-6iH7hlTUSiFahAsluO_OgKTPvXLXADFS07o-3YBWr7h8etEa';
    private static final String SECRET = 'EGMuy2BPfc_QbxIRYaO9OES2l8Nf5fHE5zwfv95YGR6qTF1U4XxBwkKp-TXxfqaIk7nwfZ3GF4o7XWQJ';

    @AuraEnabled
    public static String createPayPalOrder(Decimal amount, String description, 
                                           String returnUrl, String cancelUrl) {
        try {
            System.debug('Starting PayPal order creation');
            System.debug('Amount: ' + amount);
            System.debug('Description: ' + description);
            System.debug('ReturnUrl: ' + returnUrl);
            System.debug('CancelUrl: ' + cancelUrl);
            
            // First, get an access token
            String accessToken = getAccessToken();
            System.debug('Access token obtained: ' + (accessToken != null));
            
            // Then create the order
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SANDBOX_BASE_URL + '/v2/checkout/orders');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            
            String requestBody = '{' +
                '"intent": "CAPTURE",' +
                '"purchase_units": [{' +
                    '"amount": {' +
                        '"currency_code": "PHP",' +
                        '"value": "' + String.valueOf(amount.setScale(2)) + '"' +
                    '},' +
                    '"description": "' + description + '"' +
                '}],' +
                '"application_context": {' +
                    '"return_url": "' + returnUrl + '",' +
                    '"cancel_url": "' + cancelUrl + '",' +
                    '"brand_name": "Hotel Reservation System",' +
                    '"shipping_preference": "NO_SHIPPING",' +
                    '"user_action": "PAY_NOW",' +
                    '"landing_page": "LOGIN"' +
                '}' +
            '}';
            
            System.debug('Request body: ' + requestBody);
            req.setBody(requestBody);
            
            // Set timeout to 120 seconds
            req.setTimeout(120000);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Debug response
            System.debug('Response status: ' + res.getStatusCode());
            System.debug('Response body: ' + res.getBody());
            
            // Process the response
            if (res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> links = (List<Object>) responseMap.get('links');
                
                for (Object linkObj : links) {
                    Map<String, Object> link = (Map<String, Object>) linkObj;
                    if (link.get('rel') == 'approve') {
                        String approvalUrl = (String) link.get('href');
                        System.debug('Approval URL found: ' + approvalUrl);
                        return approvalUrl;
                    }
                }
                
                throw new PayPalException('Approval URL not found in PayPal response');
            } else {
                throw new PayPalException('PayPal API Error (' + res.getStatusCode() + '): ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in createPayPalOrder: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error creating PayPal order: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean capturePayPalPayment(String orderId) {
        try {
            System.debug('Starting PayPal payment capture for order: ' + orderId);
            
            // Get an access token
            String accessToken = getAccessToken();
            
            // Call the capture endpoint
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SANDBOX_BASE_URL + '/v2/checkout/orders/' + orderId + '/capture');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody('{}'); // Empty JSON body required for capture
            
            // Set timeout
            req.setTimeout(120000);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Debug response
            System.debug('Capture response status: ' + res.getStatusCode());
            System.debug('Capture response body: ' + res.getBody());
            
            // Process the response
            if (res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String status = (String) responseMap.get('status');
                System.debug('Capture status: ' + status);
                return status == 'COMPLETED';
            } else {
                throw new PayPalException('PayPal API Error (' + res.getStatusCode() + '): ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in capturePayPalPayment: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error capturing PayPal payment: ' + e.getMessage());
        }
    }

    private static String getAccessToken() {
        try {
            System.debug('Getting PayPal access token');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SANDBOX_BASE_URL + '/v1/oauth2/token');
            req.setMethod('POST');
            
            // Set up Basic authentication with client ID and secret
            String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(CLIENT_ID + ':' + SECRET));
            req.setHeader('Authorization', authHeader);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('grant_type=client_credentials');
            
            // Set timeout
            req.setTimeout(120000);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Debug response
            System.debug('Token response status: ' + res.getStatusCode());
            
            // Process the response
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String token = (String) responseMap.get('access_token');
                System.debug('Access token received successfully');
                return token;
            } else {
                System.debug('Token response error: ' + res.getBody());
                throw new PayPalException('Failed to get PayPal access token: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in getAccessToken: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new PayPalException('Error getting PayPal access token: ' + e.getMessage());
        }
    }
    
    // Custom exception class
    public class PayPalException extends Exception {}
}