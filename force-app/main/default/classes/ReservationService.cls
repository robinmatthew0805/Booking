public without sharing class ReservationService {
    // Email template IDs - replace these with your actual template IDs
    private static final Id CHECKIN_EMAIL_TEMPLATE_ID = '00XQy00000CKI6jMAH';  // Replace with your Check-In template ID
    private static final Id CHECKOUT_EMAIL_TEMPLATE_ID = '00XQy00000CKK25MAH'; // Replace with your Check-Out template ID
    
    /**
     * Create a room key for a reservation
     * JSON string containing key details
     */
    public static String createRoomKey(String keyData) {
        try {
            // Parse JSON data
            Map<String, Object> keyMap = (Map<String, Object>) JSON.deserializeUntyped(keyData);
            String reservationId = (String) keyMap.get('reservationID');
            
            // Handle potentially numeric values properly
            String roomNumber;
            Object roomNumberObj = keyMap.get('roomNumber');
            if (roomNumberObj instanceof Integer) {
                roomNumber = String.valueOf(roomNumberObj);
            } else {
                roomNumber = (String) roomNumberObj;
            }
            
            String guestName = (String) keyMap.get('guestName');
            String expiryDateStr = (String) keyMap.get('expiryDate');
            
            // Handle potentially numeric floorNumber
            String floorNumber;
            Object floorNumberObj = keyMap.get('floorNumber');
            if (floorNumberObj instanceof Integer) {
                floorNumber = String.valueOf(floorNumberObj);
            } else {
                floorNumber = (String) floorNumberObj;
            }
            
            String hashResult = (String) keyMap.get('hashResult');
            
            // Since we can't filter on Hashed_QR_Code__c, get all keys for the reservation 
            // and check the hash value in Apex code
            List<Room_and_Floor_Key__c> existingKeys = [
                SELECT Id, Hashed_QR_Code__c 
                FROM Room_and_Floor_Key__c 
                WHERE Reservation_ID__c = :reservationId
            ];
            
            // Check if any existing key has a matching hash
            for (Room_and_Floor_Key__c key : existingKeys) {
                if (key.Hashed_QR_Code__c == hashResult) {
                    return key.Id;  // Return existing key ID
                }
            }
            
            // Parse expiry date
            Datetime expiryDate = Datetime.valueOf(expiryDateStr.replace('T', ' ') + ':00');

            // Create the Room and Floor Key record
            Room_and_Floor_Key__c key = new Room_and_Floor_Key__c(
                Reservation_ID__c = reservationId,
                Room_No__c = roomNumber,
                Expiry_Date__c = expiryDate,
                Floor_No__c = floorNumber,
                Hashed_QR_Code__c = hashResult
            );
            
            insert key;

            // Create a log entry for check-in
            Log__c log = new Log__c(
                Guest__c = guestName,
                Reservation__c = reservationId,
                Action__c = 'Checked-in'
            );

            insert log;
            
            // Update the reservation status to Checked In if not already
            Reservation__c res = [SELECT Id, Status__c, Guest_Name__c FROM Reservation__c WHERE Id = :reservationId LIMIT 1];
            if (res.Status__c != 'Checked-in') {
                res.Status__c = 'Checked-in';
                update res;
                
                // Send check-in confirmation email
                sendCheckInEmail(res);
            }
            
            return key.Id;
        } catch (Exception e) {
            System.debug('Error in createRoomKey: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating room key: ' + e.getMessage());
        }
    }
    
    // Check out a reservation - Reservation ID to check out
    public static Boolean checkOutReservation(String bookingNumber) {
        try {
            // Get the reservation
            Reservation__c res = [
                SELECT Id, Status__c, Guest_Name__r.Name, Guest_Name__c
                FROM Reservation__c
                WHERE Id = :bookingNumber
                LIMIT 1
            ];
            
            if (res == null) {
                throw new AuraHandledException('Reservation not found');
            }
            
            // Find and deactivate any associated keys
            List<Room_and_Floor_Key__c> keys = [
                SELECT Id
                FROM Room_and_Floor_Key__c
                WHERE Reservation_ID__c = :bookingNumber
            ];
            
            if (!keys.isEmpty()) {
                for (Room_and_Floor_Key__c key : keys) {
                    key.Expiry_Date__c = Datetime.now();
                }
                update keys;
            }
            
            // Update reservation status
            res.Status__c = 'Checked-out';
            update res;
            
            // Create a log entry for checkout
            Log__c log = new Log__c(
                Guest__c = res.Guest_Name__c,
                Reservation__c = bookingNumber,
                Action__c = 'Checked-out'
            );
            insert log;
            
            // Send check-out confirmation email
            sendCheckOutEmail(res);
            
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking out reservation: ' + e.getMessage());
        }
    }
    
    /**
     * Send check-in confirmation email to the guest
     * @param reservation The reservation record
     */
    private static void sendCheckInEmail(Reservation__c reservation) {
        try {
            if (reservation != null && reservation.Guest_Name__c != null) {
                System.debug('Sending check-in email for reservation: ' + reservation.Id);
                
                // Create a new SingleEmailMessage
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 
                email.setTemplateId(CHECKIN_EMAIL_TEMPLATE_ID); 
                email.setTargetObjectId(reservation.Guest_Name__c); 
                email.setWhatId(reservation.Id); 
                email.setSaveAsActivity(true);
                
                // Send the email
                Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                
                // Log results
                for (Messaging.SendEmailResult result : results) {
                    if (result.isSuccess()) {
                        System.debug('SUCCESS: Check-in email sent successfully');
                    } else {
                        for (Messaging.SendEmailError error : result.getErrors()) {
                            System.debug('ERROR: Failed to send check-in email: ' + error.getMessage());
                        }
                    }
                }
            } else {
                System.debug('Cannot send check-in email: Missing contact information for reservation');
            }
        } catch (Exception e) {
            // Log the error but don't throw an exception to prevent transaction rollback
            System.debug('Error sending check-in email: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    // Send check-out confirmation email to the guest - reservation The reservation record
    private static void sendCheckOutEmail(Reservation__c reservation) {
        try {
            if (reservation != null && reservation.Guest_Name__c != null) {
                System.debug('Sending check-out email for reservation: ' + reservation.Id);
                
                // Create a new SingleEmailMessage
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 
                email.setTemplateId(CHECKOUT_EMAIL_TEMPLATE_ID); 
                email.setTargetObjectId(reservation.Guest_Name__c); 
                email.setWhatId(reservation.Id); 
                email.setSaveAsActivity(true);
                
                // Send the email
                Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                
                // Log results
                for (Messaging.SendEmailResult result : results) {
                    if (result.isSuccess()) {
                        System.debug('SUCCESS: Check-out email sent successfully');
                    } else {
                        for (Messaging.SendEmailError error : result.getErrors()) {
                            System.debug('ERROR: Failed to send check-out email: ' + error.getMessage());
                        }
                    }
                }
            } else {
                System.debug('Cannot send check-out email: Missing contact information for reservation');
            }
        } catch (Exception e) {
            // Log the error but don't throw an exception to prevent transaction rollback
            System.debug('Error sending check-out email: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Retrieve a reservation by booking number, guest name, and PIN
     * bookingNumber Booking number of the reservation
     * guestName Name of the guest
     * pin PIN for the reservation
     */
    public static Reservation__c getReservationByDetails(String bookingNumber, String guestName, String pin) {
        try {
            // First query just to check if the PIN matches and the reservation is not checked out
            List<Reservation__c> reservations = [
                SELECT Id, Guest_Name__r.Name, Guest_Name__c, Check_In__c, Check_Out__c, 
                       Room__r.Room_Number__c, Room__r.Floor__c, Room_Type__c, Payment_Status__c, 
                       Status__c, Special_Requests__c, PIN__c
                FROM Reservation__c
                WHERE Booking_Number__c = :bookingNumber
                AND Guest_Name__c = :guestName
                AND PIN__c = :pin
                AND Status__c != 'Checked-out'
                LIMIT 1
            ];

            // If no reservation found with matching PIN or if it's checked out, return null
            if (reservations.isEmpty()) {
                System.debug('No active reservation found with matching PIN');
                return null;
            }
            
            // Now check if the guest name matches
            return reservations[0];

        } catch (Exception e) {
            System.debug('Error retrieving reservation: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Retrieve the existing active QR code for a reservation
    public static String getExistingQRCode(String reservationId) {
        try {
            // Get all keys for the reservation and filter for active ones
            List<Room_and_Floor_Key__c> keys = [
                SELECT Id, Hashed_QR_Code__c, Expiry_Date__c
                FROM Room_and_Floor_Key__c
                WHERE Reservation_ID__c = :reservationId
                ORDER BY CreatedDate DESC
            ];
            
            Datetime now = Datetime.now();
            
            // Filter in Apex for active keys
            for (Room_and_Floor_Key__c key : keys) {
                if (key.Expiry_Date__c > now && key.Hashed_QR_Code__c != null) {
                    return key.Hashed_QR_Code__c;
                }
            }
            
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving existing QR code: ' + e.getMessage());
        }
    }
}