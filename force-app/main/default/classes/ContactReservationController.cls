public with sharing class ContactReservationController {
    //  Helper method to standardize check-in and check-out times
    //  Check-in time is set to 2:00 PM (14:00)
    //   Check-out time is set to 11:00 AM (11:00)
    private static void standardizeCheckInOutTimes(Reservation__c reservation) {
        if (reservation.Check_In__c != null) {
            // Get the date components
            Date checkInDate = reservation.Check_In__c.date();
            // Create a new DateTime with the same date but at 2:00 PM
            reservation.Check_In__c = DateTime.newInstance(
                checkInDate.year(), 
                checkInDate.month(), 
                checkInDate.day(), 
                14, // 14:00 = 2:00 PM
                0,  // 0 minutes
                0   // 0 seconds
            );
        }
        
        if (reservation.Check_Out__c != null) {
            // Get the date components
            Date checkOutDate = reservation.Check_Out__c.date();
            // Create a new DateTime with the same date but at 11:00 AM
            reservation.Check_Out__c = DateTime.newInstance(
                checkOutDate.year(), 
                checkOutDate.month(), 
                checkOutDate.day(), 
                11, // 11:00 = 11:00 AM
                0,  // 0 minutes
                0   // 0 seconds
            );
        }
    }

    // Get available rooms based on date range - OPTIMIZED FOR GUEST USERS
    @AuraEnabled
    public static List<Room__c> getAvailableRooms(String checkInDateTime, String checkOutDateTime) {
        System.debug('Starting getAvailableRooms method');
        System.debug('User: ' + UserInfo.getUserName() + ', IsGuest: ' + (UserInfo.getUserType() == 'Guest'));
        System.debug('Input dates: checkIn=' + checkInDateTime + ', checkOut=' + checkOutDateTime);
        
        try {
            // STEP 1: Parse the date strings to Datetime objects
            Datetime checkIn;
            Datetime checkOut;
            
            try {
                // Remove any timezone part to avoid parsing issues
                if (checkInDateTime.contains('T')) {
                    String checkInDateStr = checkInDateTime.split('T')[0] + ' 00:00:00';
                    checkIn = Datetime.valueOf(checkInDateStr);
                } else {
                    checkIn = Datetime.valueOf(checkInDateTime + ' 00:00:00');
                }
                
                if (checkOutDateTime.contains('T')) {
                    String checkOutDateStr = checkOutDateTime.split('T')[0] + ' 00:00:00';
                    checkOut = Datetime.valueOf(checkOutDateStr);
                } else {
                    checkOut = Datetime.valueOf(checkOutDateTime + ' 00:00:00');
                }
            } catch (Exception e) {
                System.debug('Date parsing error: ' + e.getMessage());
                // Alternative parsing attempt
                checkIn = Datetime.valueOf(checkInDateTime.replace('T', ' ').substring(0, 19));
                checkOut = Datetime.valueOf(checkOutDateTime.replace('T', ' ').substring(0, 19));
            }
            
            System.debug('Parsed Check-in: ' + checkIn + ', Check-out: ' + checkOut);
            
            // STEP 2: Get all available rooms first
            List<Room__c> allAvailableRooms = [
                SELECT Id, Name, Room_Number__c, Room_Type__c, Price_Per_Night__c, Features__c, Floor__c, Status__c
                FROM Room__c
                WHERE Status__c = 'Available'
                ORDER BY Price_Per_Night__c ASC
            ];
            
            System.debug('Found ' + allAvailableRooms.size() + ' rooms with Available status');
            
            // Early exit if no rooms are available
            if (allAvailableRooms.isEmpty()) {
                return new List<Room__c>();
            }
            
            // STEP 3: Get all room IDs to use in the next query
            Set<Id> allRoomIds = new Set<Id>();
            for (Room__c room : allAvailableRooms) {
                allRoomIds.add(room.Id);
            }
            
            // STEP 4: Find booked rooms within the date range
            // This split approach is more guest-user friendly than a complex query
            List<Reservation__c> overlappingReservations = [
                SELECT Room__c 
                FROM Reservation__c 
                WHERE Room__c IN :allRoomIds
                AND ((Check_In__c <= :checkOut AND Check_Out__c >= :checkIn))
                AND (Payment_Status__c = 'Paid' OR Payment_Status__c = 'Pending')
            ];
            
            System.debug('Found ' + overlappingReservations.size() + ' overlapping reservations');
            
            // STEP 5: Create a set of booked room IDs
            Set<Id> bookedRoomIds = new Set<Id>();
            for (Reservation__c res : overlappingReservations) {
                if (res.Room__c != null) {
                    bookedRoomIds.add(res.Room__c);
                }
            }
            
            // STEP 6: Filter the available rooms to remove booked ones
            List<Room__c> finalAvailableRooms = new List<Room__c>();
            for (Room__c room : allAvailableRooms) {
                if (!bookedRoomIds.contains(room.Id)) {
                    finalAvailableRooms.add(room);
                }
            }
            
            System.debug('Returning ' + finalAvailableRooms.size() + ' available rooms after filtering out booked rooms');
            return finalAvailableRooms;
            
        } catch (Exception e) {
            System.debug('Error in getAvailableRooms: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error getting available rooms: ' + e.getMessage());
        }
    }
            
    
    // Process PayPal payment
    @AuraEnabled
    public static String startPayPalPayment(
        Contact contactData, 
        Reservation__c reservationData, 
        String roomId, 
        Decimal amount, 
        String returnUrl, 
        String cancelUrl
    ) {
        String methodName = 'startPayPalPayment';
        System.debug(LoggingLevel.INFO, methodName + ' - Start with params: roomId=' + roomId 
                     + ', amount=' + amount + ', returnUrl=' + returnUrl + ', cancelUrl=' + cancelUrl);
        
        try {
            // Validate inputs
            if (String.isBlank(roomId)) {
                throw new AuraHandledException('Room ID is required');
            }
            
            if (String.isBlank(returnUrl) || String.isBlank(cancelUrl)) {
                throw new AuraHandledException('Return URL and Cancel URL are required');
            }
            
            // Store reservation data in session storage
            String tempReservationId = 'TEMP-' + String.valueOf(Datetime.now().getTime());
            
            // Create a description for the payment
            String description = 'Hotel Reservation';
            if (!String.isBlank(reservationData.Room_Type__c)) {
                description += ' - ' + reservationData.Room_Type__c;
            }
            
            // Clean the description to avoid JSON issues
            description = description.replace('"', '\'').replace('\\', '');
            
            // Append tempReservationId to return URLs
            returnUrl = returnUrl + '&tempId=' + tempReservationId;
            cancelUrl = cancelUrl + '&tempId=' + tempReservationId;
            
            try {
                // Call PayPal API
                String redirectUrl = PayPalService.createPayPalOrder(
                    amount,
                    description,
                    returnUrl,
                    cancelUrl
                );
                
                System.debug(LoggingLevel.INFO, methodName + ' - PayPal redirect URL received: ' + redirectUrl);
                return redirectUrl;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, methodName + ' - Error from PayPalService: ' + e.getMessage());
                throw new AuraHandledException('PayPal service error: ' + e.getMessage());
            }
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, methodName + ' - AuraHandledException: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, methodName + ' - Unexpected error: ' + e.getMessage());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        } finally {
            System.debug(LoggingLevel.INFO, methodName + ' - End');
        }
    }
    
    //Process PayPal return and create reservation
    @AuraEnabled
    public static String processPayPalReturn(
        Contact contactData, 
        Reservation__c reservationData, 
        String roomId,
        String paymentId, 
        String status
    ) {
        try {
            if (status == 'success' && String.isNotBlank(paymentId)) {
                // Capture the payment
                Boolean captureSuccessful = PayPalService.capturePayPalPayment(paymentId);
                
                if (captureSuccessful) {
                    // Now delegate to the utility class for record creation
                    return ContactReservationService.processPayPalPayment(
                        contactData,
                        reservationData,
                        roomId,
                        paymentId
                    );
                } else {
                    throw new AuraHandledException('Failed to capture PayPal payment.');
                }
            } else if (status == 'cancel') {
                // Just return null for canceled payments
                return null;
            } else {
                throw new AuraHandledException('Invalid payment status.');
            }
        } catch (Exception e) {
            System.debug('Error processing PayPal return: ' + e.getMessage());
            throw new AuraHandledException('Error processing PayPal return: ' + e.getMessage());
        }
    }
    
    // Process card payment and create reservation - Simplified for simulation
    @AuraEnabled
    public static String processInFormPayment(
        Contact contactData, 
        Reservation__c reservationData, 
        String roomId,
        String cardName, 
        String cardNumber, 
        String cardExpMonth, 
        String cardExpYear, 
        String cardCVV
    ) {
        String methodName = 'processInFormPayment';
        
        // Log the method call with masked card details for security
        System.debug(LoggingLevel.INFO, methodName + ' - Start with params: roomId=' + roomId 
                    + ', cardName=' + (String.isNotBlank(cardName) ? cardName.left(2) + '****' : 'null')
                    + ', cardNumber=' + (String.isNotBlank(cardNumber) ? '****' + cardNumber.right(4) : 'null')
                    + ', expiry=' + cardExpMonth + '/' + cardExpYear);
        
        try {
            // Basic validation - just check if required fields are present
            if (String.isBlank(roomId)) {
                throw new AuraHandledException('Room ID is required');
            }
            
            // Replace the current validation block
            if (String.isBlank(cardName)) {
                throw new AuraHandledException('Card holder name is required');
            }

            if (String.isBlank(cardNumber)) {
                throw new AuraHandledException('Card number is required');
            }

            if (String.isBlank(cardExpMonth) || String.isBlank(cardExpYear)) {
                throw new AuraHandledException('Card expiration date is required');
            }

            if (String.isBlank(cardCVV)) {
                throw new AuraHandledException('Security code (CVV) is required');
            }
            
            // In a real implementation, you would call a payment processor here
            // For this simulation, we'll always simulate a successful payment
            Boolean paymentSuccessful = true;
            
            if (paymentSuccessful) {
                // Call service method to create the reservation
                String reservationId = ContactReservationService.processCardPayment(contactData, reservationData, roomId);
                
                return reservationId;
            } else {
                throw new AuraHandledException('Payment failed - card declined');
            }
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, methodName + ' - AuraHandledException: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, methodName + ' - Unexpected error: ' + e.getMessage());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        } finally {
            System.debug(LoggingLevel.INFO, methodName + ' - End');
        }
    }
}