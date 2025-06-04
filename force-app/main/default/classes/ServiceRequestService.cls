public without sharing class ServiceRequestService {
    
    // Retrieve room numbers
    public static List<String> getRoomNumbers() {
        try {
            // Query Room objects to get the actual room numbers
            List<Room__c> rooms = [
                SELECT Id, Room_Number__c 
                FROM Room__c 
                ORDER BY Room_Number__c
            ];
            
            List<String> roomOptions = new List<String>();
            for (Room__c room : rooms) {
                roomOptions.add(room.Id);
            }
            
            return roomOptions;
        } catch (Exception e) {
            System.debug('Error retrieving room numbers: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving room numbers: ' + e.getMessage());
        }
    }
    
    // Retrieve service types
    public static List<Map<String, String>> getServiceTypes() {
        try {
            // Create a list of service types relevant to hotel guests
            List<Map<String, String>> options = new List<Map<String, String>>();
            
            // Front Office
            options.add(createOption('Room Key Replacement', 'Room Key Replacement'));
            options.add(createOption('Luggage Assistance', 'Luggage Assistance'));
            options.add(createOption('Express Check-out', 'Express Check-out'));
            options.add(createOption('Late Check-out Request', 'Late Check-out Request'));
            options.add(createOption('Transportation Arrangement', 'Transportation Arrangement'));
            
            // Housekeeping
            options.add(createOption('Room Cleaning', 'Room Cleaning'));
            options.add(createOption('Turndown Service', 'Turndown Service'));
            options.add(createOption('Extra Towels', 'Extra Towels'));
            options.add(createOption('Laundry Service', 'Laundry Service'));
            options.add(createOption('Extra Amenities', 'Extra Amenities'));
            
            // Maintenance
            options.add(createOption('Air Conditioning Issue', 'Air Conditioning Issue'));
            options.add(createOption('Plumbing Issue', 'Plumbing Issue'));
            options.add(createOption('Electrical Issue', 'Electrical Issue'));
            options.add(createOption('TV/Entertainment System Issue', 'TV/Entertainment System Issue'));
            
            // Food & Beverage
            options.add(createOption('Room Service', 'Room Service'));
            options.add(createOption('Dining Reservation', 'Dining Reservation'));
            options.add(createOption('Special Dietary Request', 'Special Dietary Request'));
            options.add(createOption('Mini Bar Refill', 'Mini Bar Refill'));
            
            // Additional Services
            options.add(createOption('WiFi Assistance', 'WiFi Assistance'));
            options.add(createOption('Spa Appointment', 'Spa Appointment'));
            options.add(createOption('Wake-up Call', 'Wake-up Call'));
            options.add(createOption('Special Occasion Setup', 'Special Occasion Setup'));
            
            return options;
        } catch (Exception e) {
            System.debug('Error retrieving service types: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving service types: ' + e.getMessage());
        }
    }
    
    // Helper method to create service option map
    private static Map<String, String> createOption(String value, String label) {
        return new Map<String, String>{
            'label' => label,
            'value' => value
        };
    }
    
    // Get service cost for a specific service type
    public static Decimal getServiceCost(String serviceType) {
        try {
            // Define service costs by service type
            Map<String, Decimal> serviceCosts = new Map<String, Decimal>{
                'Room Key Replacement' => 10.00,
                'Luggage Assistance' => 10.00,
                'Express Check-out' => 10.00,
                'Late Check-out Request' => 50.00,
                'Transportation Arrangement' => 25.00,
                'Room Cleaning' => 10.00,
                'Turndown Service' => 10.00,
                'Extra Towels' => 10.00,
                'Laundry Service' => 35.00,
                'Extra Amenities' => 10.00,
                'Air Conditioning Issue' => 10.00,
                'Plumbing Issue' => 10.00,
                'Electrical Issue' => 10.00,
                'TV/Entertainment System Issue' => 10.00,
                'Room Service' => 15.00, 
                'Dining Reservation' => 20.00,
                'Special Dietary Request' => 0.00,
                'Mini Bar Refill' => 30.00,
                'WiFi Assistance' => 50.00,
                'Spa Appointment' => 85.00,
                'Wake-up Call' => 10.00,
                'Special Occasion Setup' => 50.00
            };
            
            return serviceCosts.containsKey(serviceType) ? serviceCosts.get(serviceType) : 0;
        } catch (Exception e) {
            System.debug('Error retrieving service cost: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving service cost: ' + e.getMessage());
        }
    }
    
    // Create a service request
    public static String createServiceRequest(String serviceData) {
        try {
            // Parse JSON data
            Map<String, Object> serviceMap = (Map<String, Object>) JSON.deserializeUntyped(serviceData);
            
            // Create Service object
            Service__c service = new Service__c();
            service.Service_Type__c = (String) serviceMap.get('serviceType');
            service.Service_Cost__c = (Decimal) serviceMap.get('serviceCost');
            service.Status__c = 'Pending';
            
            // Set the relationships
            service.Room_Number__c = (String) serviceMap.get('roomNumber');
            
            // Set the guest-related fields
            service.Guest_Name__c = (String) serviceMap.get('guestId');
            
            // Set the request details from the form
            service.Request_Details__c = (String) serviceMap.get('requestDetails');
            
            // Parse datetime string
            String requestedDateTime = (String) serviceMap.get('requestedDateTime');
            service.Requested_Date_Time__c = Datetime.valueOf(requestedDateTime.replace('T', ' ') + ':00');
            
            // Insert record
            insert service;
            
            return service.Id;
        } catch (Exception e) {
            System.debug('Error creating service request: ' + e.getMessage());
            throw new AuraHandledException('Error creating service request: ' + e.getMessage());
        }
    }
    
    //  Get current guest information (placeholder method)
    public static Map<String, Object> getCurrentGuestInfo() {
        try {
            // In a real implementation, this would check if the current user is a guest
            // and return their information
            // For now, we'll always return null to show the manual form
            return null;
        } catch (Exception e) {
            System.debug('Error retrieving guest information: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving guest information: ' + e.getMessage());
        }
    }
    
    // Validate reservation details
    public static Map<String, Object> validateReservation(String guestName, String bookingNumber, String roomPin, String requestedDateTime) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            
            // Parse the requested datetime
            Datetime requestedDT = Datetime.valueOf(requestedDateTime.replace('T', ' ') + ':00');
            Date requestedDate = requestedDT.dateGMT();
            
            // Find the reservation using guest name, PIN, and booking number
            List<Reservation__c> reservations = [
                SELECT 
                    Id,
                    Guest_Name__c,
                    Room__c,
                    Check_In__c,
                    Check_out__c,
                    PIN__c,
                    Booking_Number__c,
                    Status__c
                FROM Reservation__c
                WHERE Guest_Name__r.Name = :guestName
                AND PIN__c = :roomPin
                AND Booking_Number__c = :bookingNumber
                LIMIT 1
            ];
            
            if (reservations.isEmpty()) {
                result.put('isValid', false);
                result.put('errorMessage', 'No reservation found matching the provided guest name, booking number, and PIN. Please check your information and try again.');
                return result;
            }
            
            Reservation__c reservation = reservations[0];
            
            // Check if reservation is active/checked-in
            if (reservation.Status__c != 'Checked-in') {
                result.put('isValid', false);
                result.put('errorMessage', 'Reservation is not active. Only checked-in guests can request services.');
                return result;
            }
            
            // Check if requested date is within reservation period
            if (requestedDate < reservation.Check_In__c || requestedDate > reservation.Check_out__c) {
                result.put('isValid', false);
                result.put('errorMessage', 'Requested service date must be during your stay (' + 
                            reservation.Check_In__c.format() + ' to ' + 
                            reservation.Check_out__c.format() + ').');
                return result;
            }
            
            // Get the associated room
            Room__c room;
            try {
                room = [
                    SELECT Id, Room_Number__c 
                    FROM Room__c 
                    WHERE Id = :reservation.Room__c 
                    LIMIT 1
                ];
            } catch (Exception e) {
                result.put('isValid', false);
                result.put('errorMessage', 'Error retrieving room information for this reservation.');
                return result;
            }
            
            // Get guest ID from the reservation
            String guestId = reservation.Guest_Name__c;
            
            // All validation passed
            result.put('isValid', true);
            result.put('reservation', reservation);
            result.put('room', room);
            result.put('roomId', reservation.Room__c); // Include roomId for the service request
            result.put('guestId', guestId); // Include guestId for the service request
            return result;
            
        } catch (Exception e) {
            System.debug('Error validating reservation: ' + e.getMessage());
            throw new AuraHandledException('Error validating reservation: ' + e.getMessage());
        }
    }
    
    // Get room details by room ID
    public static Map<String, String> getRoomDetails(String roomId) {
        try {
            Room__c room = [
                SELECT Id, Room_Number__c 
                FROM Room__c 
                WHERE Id = :roomId 
                LIMIT 1
            ];
            
            Map<String, String> result = new Map<String, String>();
            result.put('roomNumber', String.valueOf(room.Room_Number__c));
            return result;
        } catch (Exception e) {
            System.debug('Error retrieving room details: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving room details: ' + e.getMessage());
        }
    }
}