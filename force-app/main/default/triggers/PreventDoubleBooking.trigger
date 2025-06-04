trigger PreventDoubleBooking on Reservation__c (before insert, before update) {
    PreventConflictBookingHandler.PreventConflictBookingHandler(Trigger.new);
}