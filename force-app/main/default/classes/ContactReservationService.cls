public without sharing class ContactReservationService {
    // Process payment and create reservation records - bypasses sharing rules
    public static String processPayment(
        Contact contactData, 
        Reservation__c reservationData, 
        String roomId,
        String paymentMethod,
        String paymentReference,
        Decimal amount
    ) {
        System.debug('ContactReservationService.processPayment - Starting with payment method: ' + paymentMethod);
        
        try {
            Savepoint sp = Database.setSavepoint();
            String reservationId = null;
            
            try {
                // Check if contact with the same email already exists
                Contact existingContact = null;
                if (String.isNotBlank(contactData.Email)) {
                    List<Contact> existingContacts = [
                        SELECT Id
                        FROM Contact 
                        WHERE Email = :contactData.Email 
                        LIMIT 1
                    ];
                    
                    if (!existingContacts.isEmpty()) {
                        existingContact = existingContacts[0];
                        
                        // Use existing contact for the reservation
                        reservationData.Guest_Name__c = existingContact.Id;
                    } else {
                        // Insert new contact
                        insert contactData;
                        reservationData.Guest_Name__c = contactData.Id;
                    }
                } else {
                    // No email provided, insert new contact
                    insert contactData;
                    reservationData.Guest_Name__c = contactData.Id;
                }

                // Generate a 6-digit PIN for the reservation
                String pin = generateSixDigitPIN();
                reservationData.PIN__c = pin;

                // Set room ID and calculate total cost
                if (String.isNotBlank(roomId)) {
                    reservationData.Room__c = roomId;
                    
                    Room__c selectedRoom = [
                        SELECT Price_Per_Night__c, Room_Type__c
                        FROM Room__c
                        WHERE Id = :roomId
                        LIMIT 1
                    ];
                    
                    if (selectedRoom != null && selectedRoom.Price_Per_Night__c != null) {
                        // Standardize check-in and check-out times
                        standardizeCheckInOutTimes(reservationData);
                        
                        Integer numberOfNights = calculateNumberOfNights(reservationData.Check_In__c, reservationData.Check_Out__c);
                        Decimal totalCost = selectedRoom.Price_Per_Night__c * numberOfNights;
                        reservationData.Total_Cost__c = totalCost;
                        
                        if (String.isBlank(reservationData.Room_Type__c) && String.isNotBlank(selectedRoom.Room_Type__c)) {
                            reservationData.Room_Type__c = selectedRoom.Room_Type__c;
                        }
                    }
                } else {
                    standardizeCheckInOutTimes(reservationData);
                }
                
                // Set reservation status
                reservationData.Payment_Status__c = 'Paid';
                reservationData.Status__c = 'Confirmed';
                
                // Insert reservation and fetch ID
                insert reservationData;
                reservationId = reservationData.Id;

                // Update room status to 'Occupied'
                if (String.isNotBlank(roomId)) {
                    Room__c room = new Room__c(
                        Id = roomId,
                        Status__c = 'Occupied'
                    );
                    update room;
                }
                
                // Create a billing record
                Billing__c billing = new Billing__c(
                    Reservation_ID__c = reservationId,
                    Amount_Paid__c = amount,
                    Payment_Method__c = paymentMethod,
                    Payment_Status__c = 'Paid',
                    Payment_Date__c = System.now()
                );
                insert billing;

                reservationData.Billing__c = billing.Id;
                update reservationData;

                System.debug('About to send confirmation email for reservation: ' + reservationData);
              
                // Send confirmation email
                sendReservationConfirmationEmail(reservationData);
                
                System.debug('Successfully created reservation: ' + reservationData);

            } catch (Exception e) {
                System.debug('Error during transaction: ' + e.getMessage());
                Database.rollback(sp);
                throw e;
            }
            
            return reservationId;

        } catch (Exception e) {
            System.debug('Exception in processPayment: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Process PayPal payment specifically (for use with PayPal API)
    public static String processPayPalPayment(
        Contact contactData, 
        Reservation__c reservationData, 
        String roomId,
        String paymentId
    ) {
        return processPayment(
            contactData, 
            reservationData, 
            roomId, 
            'PayPal', 
            paymentId, 
            reservationData.Total_Cost__c
        );
    }
    
    // Process card payment specifically
    public static String processCardPayment(
        Contact contactData, 
        Reservation__c reservationData, 
        String roomId
    ) {
        // Create a reference for the transaction
        String paymentReference = 'CARD-' + String.valueOf(Datetime.now().getTime()).substring(0, 10);
        
        return processPayment(
            contactData, 
            reservationData, 
            roomId, 
            'Credit Card', 
            paymentReference, 
            reservationData.Total_Cost__c
        );
    }
    
    // Send reservation confirmation email to the guest
    private static void sendReservationConfirmationEmail(Reservation__c reservationData) {
        try {
            System.debug('Starting email send process for reservation: ' + reservationData.Id);
            
            if (reservationData != null && reservationData.Guest_Name__c != null) {
                System.debug('Guest_Name__c (Contact ID): ' + reservationData.Guest_Name__c);
                
                // Use the Lightning Email Template ID directly
                Id templateId = '00XQy00000CEMD4MAP';
                System.debug('Using Lightning email template ID: ' + templateId);
                
                try {
                    // Create a new SingleEmailMessage with simplified approach
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 
                    email.setTemplateId(templateId); 
                    email.setTargetObjectId(reservationData.Guest_Name__c); 
                    email.setWhatId(reservationData.Id); 
                    email.setSaveAsActivity(true);
                    
                    System.debug('Email prepared with template ID: ' + templateId);
                    System.debug('Email will be sent to contact ID: ' + reservationData.Guest_Name__c);
                    
                    // Send the email directly without checking for Test.isRunningTest()
                    Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                    
                    // Log results
                    for (Messaging.SendEmailResult result : results) {
                        if (result.isSuccess()) {
                            System.debug('SUCCESS: Email sent successfully');
                        } else {
                            for (Messaging.SendEmailError error : result.getErrors()) {
                                System.debug('ERROR: Failed to send email: ' + error.getMessage());
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error creating or sending email: ' + e.getMessage());
                    System.debug('Stack trace: ' + e.getStackTraceString());
                }
            } else {
                System.debug('Cannot send email: Missing contact information for reservation: ' + reservationData);
                if (reservationData == null) {
                    System.debug('Reservation is null');
                } else if (reservationData.Guest_Name__c == null) {
                    System.debug('Guest_Name__c is null');
                }
            }
        } catch (Exception e) {
            // Log the error but don't throw an exception to prevent transaction rollback
            System.debug('Error in sendReservationConfirmationEmail: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    //Helper method to standardize check-in and check-out times
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
    
    // Calculates the number of nights between two DateTime values
    private static Integer calculateNumberOfNights(DateTime checkIn, DateTime checkOut) {
        if (checkIn == null || checkOut == null) {
            return 0;
        }
        
        // Convert to milliseconds and calculate the difference
        Long diffInMillis = checkOut.getTime() - checkIn.getTime();
        
        // Convert milliseconds to days (86,400,000 ms = 1 day)
        Integer diffInDays = (Integer)(diffInMillis / (1000 * 60 * 60 * 24));
        
        // If it's a partial day, count it as a whole night
        if (Math.mod(diffInMillis, (1000 * 60 * 60 * 24)) > 0) {
            diffInDays += 1;
        }
        
        return diffInDays > 0 ? diffInDays : 0;
    }

    //Generates a random 6-digit PIN
    private static String generateSixDigitPIN() {
        Integer randomNumber = Math.round(Math.random() * 900000) + 100000; // Ensures a 6-digit number
        
        // If by chance we still get a 5-digit number, pad with leading zero
        String pinString = String.valueOf(randomNumber);
        if (pinString.length() < 6) {
            pinString = '0' + pinString;
        }
        
        return pinString;
    }
}