public with sharing class HotelDataController {
    
    // Get upcoming reservations - List of upcoming reservation records
    @AuraEnabled(cacheable=true)
    public static List<Reservation__c> getUpcomingReservations() {
        try {
            Date today = Date.today();
            return [
                SELECT 
                    Id, Name, Booking_Number__c, Check_In__c, Check_out__c, 
                    Guest_Name__r.Name, Room__r.Name, Room_Type__c,
                    Status__c, Payment_Status__c
                FROM Reservation__c
                WHERE Check_In__c >= :today
                ORDER BY Check_In__c ASC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving upcoming reservations: ' + e.getMessage());
        }
    }
    
    // Get today's check-ins - List of reservations with today's check-in date
    @AuraEnabled(cacheable=true)
    public static List<Reservation__c> getTodayCheckIns() {
        try {
            Date today = Date.today();
            return [
                SELECT 
                    Id, Name, Booking_Number__c, Check_In__c, 
                    Guest_Name__r.Name, Room__r.Name, Status__c
                FROM Reservation__c
                WHERE DAY_ONLY(Check_In__c) = :today
                ORDER BY Check_In__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving check-ins: ' + e.getMessage());
        }
    }
    
    // Get today's check-outs - List of reservations with today's check-out date
    @AuraEnabled(cacheable=true)
    public static List<Reservation__c> getTodayCheckOuts() {
        try {
            Date today = Date.today();
            return [
                SELECT 
                    Id, Name, Booking_Number__c, Check_out__c, 
                    Guest_Name__r.Name, Room__r.Name, Status__c
                FROM Reservation__c
                WHERE DAY_ONLY(Check_out__c) = :today
                ORDER BY Check_out__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving check-outs: ' + e.getMessage());
        }
    }
    
    /**
     * Search for reservations
     * searchTerm - The term to search for
     * fromDate - Start date for date range filter
     * toDate - End date for date range filter
     * List of reservations matching the search criteria
     */
    @AuraEnabled
    public static List<Reservation__c> searchReservations(String searchTerm, Date fromDate, Date toDate) {
        try {
            String searchKey = '%' + searchTerm + '%';
            String query = 'SELECT Id, Name, Booking_Number__c, Check_In__c, Check_out__c, ' +
                           'Guest_Name__r.Name, Room__r.Name, Room_Type__c, Status__c ' +
                           'FROM Reservation__c WHERE ';
            
            List<String> conditions = new List<String>();
            
            // Add search term conditions
            if (String.isNotBlank(searchTerm)) {
                conditions.add('(Name LIKE :searchKey OR Guest_Name__r.Name LIKE :searchKey OR ' + 
                              'Room__r.Name LIKE :searchKey OR Booking_Number__c LIKE :searchKey)');
            }
            
            // Add date range conditions
            if (fromDate != null) {
                conditions.add('Check_In__c >= :fromDate');
            }
            
            if (toDate != null) {
                conditions.add('Check_out__c <= :toDate');
            }
            
            // If no conditions, return all reservations
            if (conditions.isEmpty()) {
                conditions.add('Id != null');
            }
            
            query += String.join(conditions, ' AND ');
            query += ' ORDER BY Check_In__c ASC LIMIT 100';
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error searching reservations: ' + e.getMessage());
        }
    }
    
    /**
     * Update reservation status
     * reservationId - ID of the reservation to update
     * status - New status value
     * boolean indicating success
     */
    @AuraEnabled
    public static Boolean updateReservationStatus(String reservationId, String status) {
        try {
            Reservation__c reservation = [SELECT Id FROM Reservation__c WHERE Id = :reservationId LIMIT 1];
            reservation.Status__c = status;
            update reservation;
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating reservation: ' + e.getMessage());
        }
    }
    
    /**
     * Search for contacts (guests)
     * searchTerm - The term to search for
     * List of contacts matching the search criteria
     */
    @AuraEnabled
    public static List<Contact> searchGuests(String searchTerm) {
        try {
            String searchKey = '%' + searchTerm + '%';
            return [
                SELECT Id, Name, Phone, Email
                FROM Contact
                WHERE Name LIKE :searchKey
                ORDER BY Name ASC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error searching guests: ' + e.getMessage());
        }
    }

    // Get all active promotions - List of promotion records
    @AuraEnabled(cacheable=true)
    public static List<Promo_and_Advertisement__c> getPromotions() {
        try {
            Date today = Date.today();
            return [
                SELECT Id, Promo_Name__c, Target_Customers__c, Applicable_Room_Types__c, 
                       Discount_Percentage__c, Start_Date__c, End_Date__c, Additional_Details__c
                FROM Promo_and_Advertisement__c
                WHERE Start_Date__c <= :today AND End_Date__c >= :today
                ORDER BY End_Date__c ASC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving promotions: ' + e.getMessage());
        }
    }

    /**
     * Search for promotions based on filters
     * @param promoName - The promotion name to search for
     * @param targetCustomer - The target customer type
     * @param activeDate - The date when promotion should be active
     * @return List of promotions matching the search criteria
     */
    @AuraEnabled
    public static List<Promo_and_Advertisement__c> searchPromotions(String promoName, String targetCustomer, Date activeDate) {
        try {
            String searchName = '%' + (promoName != null ? promoName : '') + '%';
            String query = 'SELECT Id, Name, Description__c, Discount_Percentage__c, Start_Date__c, ' +
                        'End_Date__c, Target_Customer__c, Promo_Code__c, Status__c ' +
                        'FROM Promo_and_Advertisement__c WHERE ';
            
            List<String> conditions = new List<String>();
            
            // Add name search condition
            if (String.isNotBlank(promoName)) {
                conditions.add('Name LIKE :searchName');
            }
            
            // Add target customer condition
            if (String.isNotBlank(targetCustomer)) {
                conditions.add('Target_Customer__c = :targetCustomer');
            }
            
            // Add active date condition
            if (activeDate != null) {
                conditions.add('Start_Date__c <= :activeDate AND End_Date__c >= :activeDate');
            }
            
            // If no conditions, return all promotions
            if (conditions.isEmpty()) {
                conditions.add('Id != null');
            }
            
            query += String.join(conditions, ' AND ');
            query += ' ORDER BY End_Date__c ASC LIMIT 100';
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error searching promotions: ' + e.getMessage());
        }
    }
}