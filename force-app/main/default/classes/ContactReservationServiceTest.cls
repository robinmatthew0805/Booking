@isTest
private class ContactReservationServiceTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create a test room
        Room__c testRoom = new Room__c(
            Room_Number__c = 101,
            Room_Type__c = 'Single',
            Price_Per_Night__c = 100.00,
            Features__c = 'Free WiFi;Sea view',
            Floor__c = 1,
            Status__c = 'Available'
        );
        insert testRoom;
        
        // Create a contact for testing
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Guest',
            Email = 'test@example.com',
            Phone = '1234567890'
        );
        insert testContact;
    }
    
    // Method for testing SingleizeCheckInOutTimes
    public static void testSingleizeTimes(Reservation__c reservation) {
        if (reservation.Check_In__c != null) {
            Date checkInDate = reservation.Check_In__c.date();
            reservation.Check_In__c = DateTime.newInstance(
                checkInDate.year(), 
                checkInDate.month(), 
                checkInDate.day(), 
                14, 
                0,  
                0   
            );
        }
        
        if (reservation.Check_Out__c != null) {
            Date checkOutDate = reservation.Check_Out__c.date();
            reservation.Check_Out__c = DateTime.newInstance(
                checkOutDate.year(), 
                checkOutDate.month(), 
                checkOutDate.day(), 
                11, 
                0,  
                0   
            );
        }
    }
    
    // Test processPayment method
    @isTest
    static void testProcessPayment() {
        // Get test data
        Room__c room = [SELECT Id, Price_Per_Night__c FROM Room__c LIMIT 1];
        
        // Create test contact
        Contact contact = new Contact(
            FirstName = 'New',
            LastName = 'Customer',
            Email = 'new.customer@example.com',
            Phone = '5555555555'
        );
        
        // Create test reservation
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 200.00,
            Special_Requests__c = 'None'
        );
        
        Test.startTest();
        // Disable email sending for tests
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processPayment(
            contact, 
            reservation, 
            room.Id,
            'Credit Card',
            'TEST-PAYMENT-REF',
            200.00
        );
        Test.stopTest();
        
        // Verify reservation was created
        System.assertNotEquals(null, reservationId, 'Reservation should be created');
        
        // Verify reservation details
        Reservation__c createdReservation = [
            SELECT Id, Guest_Name__c, Room__c, Payment_Status__c, Status__c, PIN__c, Billing__c
            FROM Reservation__c 
            WHERE Id = :reservationId
        ];
        
        System.assertEquals('Paid', createdReservation.Payment_Status__c, 'Payment status should be Paid');
        System.assertEquals('Confirmed', createdReservation.Status__c, 'Reservation status should be Confirmed');
        System.assertNotEquals(null, createdReservation.PIN__c, 'PIN should be generated');
        System.assertNotEquals(null, createdReservation.Billing__c, 'Billing record should be created');
        
        // Verify billing record
        Billing__c billing = [
            SELECT Amount_Paid__c, Payment_Method__c, Payment_Status__c
            FROM Billing__c 
            WHERE Reservation_ID__c = :reservationId
        ];
        
        System.assertEquals(200.00, billing.Amount_Paid__c, 'Billing amount should match');
        System.assertEquals('Credit Card', billing.Payment_Method__c, 'Payment method should match');
        System.assertEquals('Paid', billing.Payment_Status__c, 'Billing status should be Paid');
        
        // Verify room status
        Room__c updatedRoom = [SELECT Status__c FROM Room__c WHERE Id = :room.Id];
        System.assertEquals('Occupied', updatedRoom.Status__c, 'Room status should be updated to Occupied');
    }
    
    // Test processPayment with existing contact
    @isTest
    static void testProcessPaymentExistingContact() {
        // Get existing contact
        Contact existingContact = [SELECT Id, Email FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        
        // Create a new instance of the contact to simulate the form submission
        Contact contactForm = new Contact(
            FirstName = 'Updated',
            LastName = 'Name',
            Email = 'test@example.com', // Same email as existing contact
            Phone = '9999999999'
        );
        
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 200.00
        );
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processPayment(
            contactForm, 
            reservation, 
            room.Id,
            'PayPal',
            'PAYPAL-ID-123',
            200.00
        );
        Test.stopTest();
        
        // Verify reservation was created
        System.assertNotEquals(null, reservationId, 'Reservation should be created');
        
        // Verify existing contact was used
        Reservation__c createdReservation = [
            SELECT Guest_Name__c
            FROM Reservation__c 
            WHERE Id = :reservationId
        ];
        
        System.assertEquals(existingContact.Id, createdReservation.Guest_Name__c, 
                           'Existing contact should be used');
    }
    
    // Test processPayment without email
    @isTest
    static void testProcessPaymentNoEmail() {
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        
        // Create contact without email
        Contact contactNoEmail = new Contact(
            FirstName = 'No',
            LastName = 'Email',
            Phone = '1231231234'
        );
        
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 200.00
        );
        
        Test.startTest();
        // Disable email sending for tests
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processPayment(
            contactNoEmail, 
            reservation, 
            room.Id,
            'Credit Card',
            'TEST-REF',
            200.00
        );
        Test.stopTest();
        
        // Verify new contact was created
        List<Contact> newContacts = [SELECT Id FROM Contact WHERE LastName = 'Email'];
        System.assertEquals(1, newContacts.size(), 'New contact should be created');
        
        // Verify reservation points to the new contact
        Reservation__c createdReservation = [
            SELECT Guest_Name__c
            FROM Reservation__c 
            WHERE Id = :reservationId
        ];
        
        System.assertEquals(newContacts[0].Id, createdReservation.Guest_Name__c, 
                           'Reservation should point to the new contact');
    }
    
    // Test processPayPalPayment method
    @isTest
    static void testProcessPayPalPayment() {
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        
        Contact contact = new Contact(
            FirstName = 'PayPal',
            LastName = 'User',
            Email = 'paypal@example.com'
        );
        
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 300.00
        );
        
        Test.startTest();
        // Disable email sending for tests
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processPayPalPayment(
            contact, 
            reservation, 
            room.Id,
            'PAYPAL-12345'
        );
        Test.stopTest();
        
        // Verify payment method is recorded correctly
        Billing__c billing = [
            SELECT Payment_Method__c 
            FROM Billing__c 
            WHERE Reservation_ID__c = :reservationId
        ];
        
        System.assertEquals('PayPal', billing.Payment_Method__c, 'Payment method should be PayPal');
    }
    
    // Test processCardPayment method
    @isTest
    static void testProcessCardPayment() {
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        
        Contact contact = new Contact(
            FirstName = 'Card',
            LastName = 'User',
            Email = 'card@example.com'
        );
        
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 250.00
        );
        
        Test.startTest();
        // Disable email sending for tests
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processCardPayment(
            contact, 
            reservation, 
            room.Id
        );
        Test.stopTest();
        
        // Verify payment method is recorded correctly
        Billing__c billing = [
            SELECT Payment_Method__c 
            FROM Billing__c 
            WHERE Reservation_ID__c = :reservationId
        ];
        
        System.assertEquals('Credit Card', billing.Payment_Method__c, 'Payment method should be Credit Card');
    }
    
    // Test PIN generation
    @isTest
    static void testPINGeneration() {
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        
        Contact contact = new Contact(
            FirstName = 'PIN',
            LastName = 'Test',
            Email = 'pin@example.com'
        );
        
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 200.00
        );
        
        Test.startTest();
        // Disable email sending for tests
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processPayment(
            contact, 
            reservation, 
            room.Id,
            'Credit Card',
            'TEST-PIN',
            200.00
        );
        Test.stopTest();
        
        // Verify PIN was generated
        Reservation__c createdReservation = [
            SELECT PIN__c
            FROM Reservation__c 
            WHERE Id = :reservationId
        ];
        
        System.assertNotEquals(null, createdReservation.PIN__c, 'PIN should be generated');
        System.assertEquals(6, createdReservation.PIN__c.length(), 'PIN should be 6 digits');
        
        // Verify PIN is numeric
        Boolean isNumeric = createdReservation.PIN__c.isNumeric();
        System.assert(isNumeric, 'PIN should be numeric');
    }
    
    // Test night calculation
    @isTest
    static void testNightCalculation() {
        Room__c room = [SELECT Id, Price_Per_Night__c FROM Room__c LIMIT 1];
        
        Contact contact = new Contact(
            FirstName = 'Night',
            LastName = 'Calculator',
            Email = 'nights@example.com'
        );
        
        // Set specific check-in and check-out times to test night calculation
        DateTime checkIn = DateTime.newInstance(2023, 1, 1, 14, 0, 0);
        DateTime checkOut = DateTime.newInstance(2023, 1, 5, 11, 0, 0);
        
        Reservation__c reservation = new Reservation__c(
            Room_Type__c = 'Single',
            Check_In__c = checkIn,
            Check_Out__c = checkOut
        );
        
        Test.startTest();
        // Disable email sending for tests
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        
        String reservationId = ContactReservationService.processPayment(
            contact, 
            reservation, 
            room.Id,
            'Credit Card',
            'TEST-NIGHTS',
            400.00 // Expected to be recalculated based on nights
        );
        Test.stopTest();
        
        // Verify total cost calculation
        Reservation__c createdReservation = [
            SELECT Total_Cost__c
            FROM Reservation__c 
            WHERE Id = :reservationId
        ];
        
        // Expected: 4 nights * $100 per night = $400
        System.assertEquals(400.00, createdReservation.Total_Cost__c, 'Total cost should be calculated correctly');
    }
    
    // Mock for HTTP callouts
    private class DummyHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true}');
            res.setStatusCode(200);
            return res;
        }
    }
}