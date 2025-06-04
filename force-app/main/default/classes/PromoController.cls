public with sharing class PromoController {
    @AuraEnabled(cacheable=true)
    public static List<Promo_and_Advertisement__c> getActivePromotions() {
        try {
            return PromoService.getActivePromotions();
        } catch (Exception e) {
            System.debug('Error retrieving promotions in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving promotions: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getRoomTypes() {
        try {
            return PromoService.getRoomTypes();
        } catch (Exception e) {
            System.debug('Error retrieving room types in controller: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving room types: ' + e.getMessage());
        }
    }
}