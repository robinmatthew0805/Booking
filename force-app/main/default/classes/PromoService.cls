public without sharing class PromoService {
    
    // Retrieve active promotions for the current date - List of active Promo_and_Advertisement__c records
    public static List<Promo_and_Advertisement__c> getActivePromotions() {
        try {
            // Get current date
            Date today = Date.today();
            
            // Query active promotions (start date <= today <= end date)
            return [
                SELECT Id, Promo_Name__c, Target_Customers__c, Applicable_Room_Types__c, 
                       Discount_Percentage__c, Start_Date__c, End_Date__c, Additional_Details__c
                FROM Promo_and_Advertisement__c
                WHERE Start_Date__c <= :today 
                AND End_Date__c >= :today
                ORDER BY Discount_Percentage__c DESC
            ];
        } catch (Exception e) {
            System.debug('Error retrieving promotions: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving promotions: ' + e.getMessage());
        }
    }

    // Retrieve a list of available room types - List of room type strings
    public static List<String> getRoomTypes() {
        try {
            return new List<String>{
                'Single', 'Double', 'Suite', 'Premium'
            };
        } catch (Exception e) {
            System.debug('Error retrieving room types: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving room types: ' + e.getMessage());
        }
    }
}