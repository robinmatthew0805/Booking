public with sharing class ServiceRequestController {
    @AuraEnabled(cacheable=true)
    public static List<String> getRoomNumbers() {
        try {
            return ServiceRequestService.getRoomNumbers();
        } catch (Exception e) {
            System.debug('Error retrieving room numbers in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving room numbers: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceTypes() {
        try {
            return ServiceRequestService.getServiceTypes();
        } catch (Exception e) {
            System.debug('Error retrieving service types in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving service types: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Decimal getServiceCost(String serviceType) {
        try {
            return ServiceRequestService.getServiceCost(serviceType);
        } catch (Exception e) {
            System.debug('Error retrieving service cost in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving service cost: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createServiceRequest(String serviceData) {
        try {
            return ServiceRequestService.createServiceRequest(serviceData);
        } catch (Exception e) {
            System.debug('Error creating service request in controller: ' + e.getMessage());
            throw new AuraHandledException('Error creating service request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> getCurrentGuestInfo() {
        try {
            return ServiceRequestService.getCurrentGuestInfo();
        } catch (Exception e) {
            System.debug('Error retrieving guest information in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving guest information: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> validateReservation(String guestName, String bookingNumber, String roomPin, String requestedDateTime) {
        try {
            return ServiceRequestService.validateReservation(guestName, bookingNumber, roomPin, requestedDateTime);
        } catch (Exception e) {
            System.debug('Error validating reservation in controller: ' + e.getMessage());
            throw new AuraHandledException('Error validating reservation: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRoomDetails(String roomId) {
        try {
            return ServiceRequestService.getRoomDetails(roomId);
        } catch (Exception e) {
            System.debug('Error retrieving room details in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving room details: ' + e.getMessage());
        }
    }
}