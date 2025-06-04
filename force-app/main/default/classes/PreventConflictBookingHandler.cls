public class PreventConflictBookingHandler {
    // Prevents double booking by checking for overlapping reservations
    public static void PreventConflictBookingHandler(List<Reservation__c> newReservations) {
        Set<Id> roomIds = new Set<Id>();

        for (Reservation__c res : newReservations) {
            if (res.Room__c != null) {
                roomIds.add(res.Room__c);
            }
        }

        if (roomIds.isEmpty()) return; // No rooms to check

        // Fetch existing reservations that overlap with the new ones
        Map<Id, List<Reservation__c>> existingReservationsMap = new Map<Id, List<Reservation__c>>();
        
        List<Reservation__c> existingReservations = [
            SELECT Id, Room__c, Check_In__c, Check_Out__c 
            FROM Reservation__c 
            WHERE Room__c IN :roomIds
            AND Payment_Status__c IN ('Paid', 'Pending')
        ];

        for (Reservation__c existing : existingReservations) {
            if (!existingReservationsMap.containsKey(existing.Room__c)) {
                existingReservationsMap.put(existing.Room__c, new List<Reservation__c>());
            }
            existingReservationsMap.get(existing.Room__c).add(existing);
        }

        for (Reservation__c newRes : newReservations) {
            if (newRes.Room__c == null || !existingReservationsMap.containsKey(newRes.Room__c)) continue;

            for (Reservation__c existing : existingReservationsMap.get(newRes.Room__c)) {
                // Skip if we're comparing the same record during an update
                if (Trigger.isUpdate && existing.Id == newRes.Id) continue;
                
                // Check for overlapping dates
                if ((newRes.Check_In__c < existing.Check_Out__c) && (newRes.Check_Out__c > existing.Check_In__c)) {
                    newRes.addError('This room is already booked during the selected dates.');
                    break; // No need to check more once we've found a conflict
                }
            }
        }
    }
}