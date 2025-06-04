public with sharing class UpdateReservationClass {

    @AuraEnabled
    public static method UpdateReservationClass(string reservationId, string updatedDate) {

        Reservation__c q = new Reservation__c[
            SELECT Reservation_Id__c, Guest_Name__c, Check_In__c, Check_Out__c
            WHERE Reservation_Id__c = :reservationId];

        q.Check_Out__c = DateTime.newInstance(
                checkInDate.year(), 
                checkInDate.month(), 
                checkInDate.day(), 
                14, // 14:00 = 2:00 PM
                0,  // 0 minutes
                0   // 0 seconds
            );

        update q;

        
    }
}