public class CheckoutStatusBatchClass implements Database.Batchable<sObject>, Database.Stateful {
    private Set<Id> setOfReservationIds = new Set<Id>();
    public Integer count = 0;
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        Date today = Date.today();
        String query = 'SELECT Id, Status__c, Room__c, Check_out__c ' +
                       'FROM Reservation__c ' +
                       'WHERE Check_out__c <= :today ' +
                       'AND Status__c != \'Checked Out\'';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Reservation__c> scope) {
        List<Reservation__c> reservationsToUpdate = new List<Reservation__c>();
        Set<Id> roomIds = new Set<Id>();
        
        // Create a map to store reservation data for logging
        Map<Id, Reservation__c> reservationMap = new Map<Id, Reservation__c>();
        
        for (Reservation__c res : scope) {
            res.Status__c = 'Checked-Out';
            reservationsToUpdate.add(res);
            setOfReservationIds.add(res.Id);
            
            // Store reservation data for logging
            reservationMap.put(res.Id, res);
            
            if(res.Room__c != null) {
                roomIds.add(res.Room__c);
            }
        }
        
        count = scope.size();
        
        // Update rooms to maintenance status
        List<Room__c> roomsToUpdate = new List<Room__c>();
        if(!roomIds.isEmpty()) {
            List<Room__c> rooms = [SELECT Id, Status__c, Cleaning_Status__c 
                                  FROM Room__c 
                                  WHERE Id IN :roomIds];
            
            for(Room__c room : rooms) {
                room.Status__c = 'Maintenance';
                room.Cleaning_Status__c = 'Needs Cleaning';
                roomsToUpdate.add(room);
            }
        }
        
        // Create logs for each reservation
        List<Log__c> logsToInsert = new List<Log__c>();
        
        // Query for guest information related to these reservations
        Map<Id, Id> reservationToGuestMap = new Map<Id, Id>();
        
        // Query to get Guest information (assuming Guest__c is the field on Reservation__c)
        // Adjust the field name if different in your org
        List<Reservation__c> reservationsWithGuests = [SELECT Id, Guest_Name__c 
                                                      FROM Reservation__c 
                                                      WHERE Id IN :setOfReservationIds];
        
        for(Reservation__c res : reservationsWithGuests) {
            if(res.Guest_Name__c != null) {
                reservationToGuestMap.put(res.Id, res.Guest_Name__c);
            }
        }
        
        // Create a log for each reservation
        for(Id resId : setOfReservationIds) {
            Log__c log = new Log__c();
            log.Action__c = 'Checked-out';
            log.Reservation__c = resId;
            
            // Set guest if available
            if(reservationToGuestMap.containsKey(resId)) {
                log.Guest__c = reservationToGuestMap.get(resId);
            }
            
            logsToInsert.add(log);
        }
        
        try {
            update reservationsToUpdate;
            
            if(!roomsToUpdate.isEmpty()) {
                update roomsToUpdate;
            }
            
            if(!logsToInsert.isEmpty()) {
                insert logsToInsert;
            }
        } catch(Exception e) {
            System.debug('Error in ReservationCheckoutBatch: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Reservation Checkout Batch Process Completed');
    }
}