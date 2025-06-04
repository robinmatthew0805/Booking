public with sharing class ReservationController {
    @AuraEnabled
    public static String createRoomKey(String keyData) {
        try {
            return ReservationService.createRoomKey(keyData);
        } catch (Exception e) {
            System.debug('Error in createRoomKey controller: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating room key: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean checkOutReservation(String bookingNumber) {
        try {
            return ReservationService.checkOutReservation(bookingNumber);
        } catch (Exception e) {
            System.debug('Error in checkOutReservation controller: ' + e.getMessage());
            throw new AuraHandledException('Error checking out reservation: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Reservation__c getReservationByDetails(String bookingNumber, String guestName, String pin) {
        try {
            return ReservationService.getReservationByDetails(bookingNumber, guestName, pin);
        } catch (Exception e) {
            System.debug('Error retrieving reservation: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getExistingQRCode(String reservationId) {
        try {
            return ReservationService.getExistingQRCode(reservationId);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving existing QR code: ' + e.getMessage());
        }
    }
}