@isTest
private class ReservationServiceTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Guest',
            Email = 'test@example.com',
            Phone = '1234567890'
        );
        insert testContact;
        
        // Create test room
        Room__c testRoom = new Room__c(
            Room_Number__c = 101,
            Room_Type__c = 'Single',
            Price_Per_Night__c = 100.00,
            Features__c = 'Sea view',
            Floor__c = 1,
            Status__c = 'Available'
        );
        insert testRoom;
        
        // Create test reservation
        Reservation__c testReservation = new Reservation__c(
            Guest_Name__c = testContact.Id,
            Room__c = testRoom.Id,
            Room_Type__c = 'Standard',
            Check_In__c = DateTime.now().addDays(1),
            Check_Out__c = DateTime.now().addDays(3),
            Total_Cost__c = 200.00,
            Payment_Status__c = 'Paid',
            Status__c = 'Confirmed',
            PIN__c = '123456',
            Special_Requests__c = 'None'
        );
        insert testReservation;
    }
    
    // Test creating a room key
    @isTest
    static void testCreateRoomKey() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create key data
        Map<String, Object> keyData = new Map<String, Object>{
            'reservationID' => reservation.Id,
            'roomNumber' => '101',
            'guestName' => 'Test Guest',
            'expiryDate' => String.valueOf(DateTime.now().addDays(3)).replace(' ', 'T').substring(0, 19),
            'floorNumber' => '1',
            'hashResult' => 'HASH12345'
        };
        
        Test.startTest();
        // Mock email sending to prevent errors
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        String keyId = ReservationService.createRoomKey(JSON.serialize(keyData));
        Test.stopTest();
        
        // Verify key was created
        System.assertNotEquals(null, keyId, 'Room key should be created');
        
        // Verify reservation was updated
        Reservation__c updatedReservation = [
            SELECT Status__c FROM Reservation__c WHERE Id = :reservation.Id
        ];
        System.assertEquals('Checked-in', updatedReservation.Status__c, 'Reservation status should be Checked-in');
        
        // Verify log was created
        List<Log__c> logs = [
            SELECT Action__c FROM Log__c WHERE Reservation__c = :reservation.Id
        ];
        System.assertEquals(1, logs.size(), 'Log entry should be created');
        System.assertEquals('Checked-in', logs[0].Action__c, 'Log action should be Checked-in');
    }
    
    // Test creating a duplicate room key (should return existing key)
    @isTest
    static void testCreateDuplicateRoomKey() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create initial key
        Room_and_Floor_Key__c initialKey = new Room_and_Floor_Key__c(
            Reservation_ID__c = reservation.Id,
            Room_No__c = '101',
            Floor_No__c = '1',
            Expiry_Date__c = DateTime.now().addDays(3),
            Hashed_QR_Code__c = 'UNIQUE_HASH_123'
        );
        insert initialKey;
        
        // Create key data with the same hash
        Map<String, Object> keyData = new Map<String, Object>{
            'reservationID' => reservation.Id,
            'roomNumber' => '101',
            'guestName' => 'Test Guest',
            'expiryDate' => String.valueOf(DateTime.now().addDays(3)).replace(' ', 'T').substring(0, 19),
            'floorNumber' => '1',
            'hashResult' => 'UNIQUE_HASH_123'
        };
        
        Test.startTest();
        // Mock email sending to prevent errors
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        String keyId = ReservationService.createRoomKey(JSON.serialize(keyData));
        Test.stopTest();
        
        // Verify the existing key ID was returned
        System.assertEquals(initialKey.Id, keyId, 'Should return existing key ID');
        
        // Verify no additional keys were created
        List<Room_and_Floor_Key__c> keys = [
            SELECT Id FROM Room_and_Floor_Key__c WHERE Reservation_ID__c = :reservation.Id
        ];
        System.assertEquals(1, keys.size(), 'No additional keys should be created');
    }
    
    // Test creating a room key with numeric values in JSON
    @isTest
    static void testCreateRoomKeyWithNumericValues() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create JSON with numeric values
        String jsonInput = '{"reservationID":"' + reservation.Id + 
                          '","roomNumber":101,' +  // Numeric room number
                          '"guestName":"Test Guest",' +
                          '"expiryDate":"' + String.valueOf(DateTime.now().addDays(3)).replace(' ', 'T').substring(0, 19) + '",' +
                          '"floorNumber":1,' +  // Numeric floor number
                          '"hashResult":"HASH_NUMERIC_TEST"}';
        
        Test.startTest();
        // Mock email sending to prevent errors
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        String keyId = ReservationService.createRoomKey(jsonInput);
        Test.stopTest();
        
        // Verify key was created with correct values
        Room_and_Floor_Key__c key = [
            SELECT Room_No__c, Floor_No__c 
            FROM Room_and_Floor_Key__c 
            WHERE Id = :keyId
        ];
        
        System.assertEquals('101', key.Room_No__c, 'Numeric room number should be converted to string');
        System.assertEquals('1', key.Floor_No__c, 'Numeric floor number should be converted to string');
    }
    
    // Test checkout process
    @isTest
    static void testCheckOutReservation() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create a room key for this reservation
        Room_and_Floor_Key__c key = new Room_and_Floor_Key__c(
            Reservation_ID__c = reservation.Id,
            Room_No__c = '101',
            Floor_No__c = '1',
            Expiry_Date__c = DateTime.now().addDays(3),
            Hashed_QR_Code__c = 'CHECKOUT_TEST_HASH'
        );
        insert key;
        
        Test.startTest();
        // Mock email sending to prevent errors
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Boolean result = ReservationService.checkOutReservation(reservation.Id);
        Test.stopTest();
        
        // Verify checkout was successful
        System.assert(result, 'Checkout should be successful');
        
        // Verify reservation status was updated
        Reservation__c updatedReservation = [
            SELECT Status__c FROM Reservation__c WHERE Id = :reservation.Id
        ];
        System.assertEquals('Checked-out', updatedReservation.Status__c, 'Reservation status should be Checked-out');
        
        // Verify key was deactivated
        Room_and_Floor_Key__c updatedKey = [
            SELECT Expiry_Date__c FROM Room_and_Floor_Key__c WHERE Id = :key.Id
        ];
        System.assert(
            updatedKey.Expiry_Date__c <= DateTime.now(), 
            'Key expiry date should be set to current time or earlier'
        );
        
        // Verify log was created
        List<Log__c> logs = [
            SELECT Action__c FROM Log__c WHERE Reservation__c = :reservation.Id AND Action__c = 'Checked-out'
        ];
        System.assertEquals(1, logs.size(), 'Checkout log entry should be created');
    }
    
    // Test getReservationByDetails with valid details
    @isTest
    static void testGetReservationByDetailsValid() {
        // Get test reservation with guest details
        Reservation__c originalReservation = [
            SELECT Id, Booking_Number__c, PIN__c, Guest_Name__r.Name
            FROM Reservation__c
            LIMIT 1
        ];
        
        Test.startTest();
        Reservation__c retrievedReservation = ReservationService.getReservationByDetails(
            originalReservation.Booking_Number__c,
            originalReservation.Guest_Name__r.Name,
            originalReservation.PIN__c
        );
        Test.stopTest();
        
        // Verify correct reservation was retrieved
        System.assertNotEquals(null, retrievedReservation, 'Reservation should be retrieved');
        System.assertEquals(originalReservation.Id, retrievedReservation.Id, 'Correct reservation should be retrieved');
    }
    
    // Test getReservationByDetails with invalid PIN
    @isTest
    static void testGetReservationByDetailsInvalidPin() {
        // Get test reservation
        Reservation__c originalReservation = [
            SELECT Id, Booking_Number__c, Guest_Name__r.Name
            FROM Reservation__c
            LIMIT 1
        ];
        
        Test.startTest();
        Reservation__c retrievedReservation = ReservationService.getReservationByDetails(
            originalReservation.Booking_Number__c,
            originalReservation.Guest_Name__r.Name,
            'WRONG_PIN'  // Invalid PIN
        );
        Test.stopTest();
        
        // Verify no reservation was retrieved
        System.assertEquals(null, retrievedReservation, 'No reservation should be retrieved with invalid PIN');
    }
    
    // Test getReservationByDetails with invalid guest name
    @isTest
    static void testGetReservationByDetailsInvalidName() {
        // Get test reservation
        Reservation__c originalReservation = [
            SELECT Id, Booking_Number__c, PIN__c
            FROM Reservation__c
            LIMIT 1
        ];
        
        Test.startTest();
        Reservation__c retrievedReservation = ReservationService.getReservationByDetails(
            originalReservation.Booking_Number__c,
            'Wrong Guest Name',  // Invalid guest name
            originalReservation.PIN__c
        );
        Test.stopTest();
        
        // Verify no reservation was retrieved
        System.assertEquals(null, retrievedReservation, 'No reservation should be retrieved with invalid guest name');
    }
    
    // Test getReservationByDetails for checked-out reservation
    @isTest
    static void testGetReservationByDetailsCheckedOut() {
        // Get test reservation
        Reservation__c reservation = [
            SELECT Id, Booking_Number__c, PIN__c, Guest_Name__r.Name
            FROM Reservation__c
            LIMIT 1
        ];
        
        // Update reservation to checked-out
        reservation.Status__c = 'Checked-out';
        update reservation;
        
        Test.startTest();
        Reservation__c retrievedReservation = ReservationService.getReservationByDetails(
            reservation.Booking_Number__c,
            reservation.Guest_Name__r.Name,
            reservation.PIN__c
        );
        Test.stopTest();
        
        // Verify no reservation was retrieved
        System.assertEquals(null, retrievedReservation, 'No reservation should be retrieved for checked-out reservation');
    }
    
    // Test getExistingQRCode with active key
    @isTest
    static void testGetExistingQRCodeActive() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create a room key with future expiry
        Room_and_Floor_Key__c key = new Room_and_Floor_Key__c(
            Reservation_ID__c = reservation.Id,
            Room_No__c = '101',
            Floor_No__c = '1',
            Expiry_Date__c = DateTime.now().addDays(3),
            Hashed_QR_Code__c = 'ACTIVE_QR_CODE'
        );
        insert key;
        
        Test.startTest();
        String qrCode = ReservationService.getExistingQRCode(reservation.Id);
        Test.stopTest();
        
        // Verify QR code was retrieved
        System.assertEquals('ACTIVE_QR_CODE', qrCode, 'Active QR code should be retrieved');
    }
    
    // Test getExistingQRCode with expired key
    @isTest
    static void testGetExistingQRCodeExpired() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create a room key with past expiry
        Room_and_Floor_Key__c key = new Room_and_Floor_Key__c(
            Reservation_ID__c = reservation.Id,
            Room_No__c = '101',
            Floor_No__c = '1',
            Expiry_Date__c = DateTime.now().addDays(-1),  // Expired key
            Hashed_QR_Code__c = 'EXPIRED_QR_CODE'
        );
        insert key;
        
        Test.startTest();
        String qrCode = ReservationService.getExistingQRCode(reservation.Id);
        Test.stopTest();
        
        // Verify no QR code was retrieved
        System.assertEquals(null, qrCode, 'No QR code should be retrieved for expired key');
    }
    
    // Test getExistingQRCode with multiple keys (should return the active one)
    @isTest
    static void testGetExistingQRCodeMultipleKeys() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create multiple keys - one expired, one active
        Room_and_Floor_Key__c expiredKey = new Room_and_Floor_Key__c(
            Reservation_ID__c = reservation.Id,
            Room_No__c = '101',
            Floor_No__c = '1',
            Expiry_Date__c = DateTime.now().addDays(-1),
            Hashed_QR_Code__c = 'EXPIRED_QR_CODE'
        );
        
        Room_and_Floor_Key__c activeKey = new Room_and_Floor_Key__c(
            Reservation_ID__c = reservation.Id,
            Room_No__c = '101',
            Floor_No__c = '1',
            Expiry_Date__c = DateTime.now().addDays(3),
            Hashed_QR_Code__c = 'ACTIVE_QR_CODE'
        );
        
        insert new List<Room_and_Floor_Key__c>{expiredKey, activeKey};
        
        Test.startTest();
        String qrCode = ReservationService.getExistingQRCode(reservation.Id);
        Test.stopTest();
        
        // Verify active QR code was retrieved
        System.assertEquals('ACTIVE_QR_CODE', qrCode, 'Active QR code should be retrieved');
    }
    
    // HTTP Mock class to handle callouts in tests
    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }
}