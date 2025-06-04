@isTest
private class PreventConflictBookingHandlerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test room
        Room__c testRoom = new Room__c(
            Room_Type__c = 'Standard',
            Status__c = 'Available'
        );
        insert testRoom;
        
        // Create a second room for testing multiple rooms
        Room__c testRoom2 = new Room__c(
            Room_Type__c = 'Deluxe',
            Status__c = 'Available'
        );
        insert testRoom2;
        
        // Create existing reservation for the first room
        Reservation__c existingReservation = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = Date.today().addDays(10),
            Check_Out__c = Date.today().addDays(15),
            Payment_Status__c = 'Paid'
        );
        insert existingReservation;
    }
    
    @isTest
    static void testNonConflictingReservation() {
        // Get the test room
        Room__c testRoom = [SELECT Id FROM Room__c WHERE Name = 'Test Room 101' LIMIT 1];
        
        // Create a new reservation with dates that don't conflict
        Reservation__c newReservation = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = Date.today().addDays(20),
            Check_Out__c = Date.today().addDays(25),
            Payment_Status__c = 'Pending'
        );
        
        // Test insertion
        Test.startTest();
        Database.SaveResult result = Database.insert(newReservation, false);
        Test.stopTest();
        
        // Verify the reservation was created successfully
        System.assert(result.isSuccess(), 'Non-conflicting reservation should be created successfully');
        
        // Query to make sure it's in the database
        List<Reservation__c> insertedReservations = [SELECT Id FROM Reservation__c WHERE Id = :result.getId()];
        System.assertEquals(1, insertedReservations.size(), 'Reservation should exist in the database');
    }
    
    @isTest
    static void testConflictingReservation() {
        // Get the test room
        Room__c testRoom = [SELECT Id FROM Room__c WHERE Name = 'Test Room 101' LIMIT 1];
        
        // Get existing reservation data to create conflict
        Reservation__c existingReservation = [
            SELECT Check_In__c, Check_Out__c 
            FROM Reservation__c 
            WHERE Room__c = :testRoom.Id 
            LIMIT 1
        ];
        
        // Create a new reservation with overlapping dates
        Reservation__c conflictingReservation = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = existingReservation.Check_In__c.addDays(-2),
            Check_Out__c = existingReservation.Check_In__c.addDays(2), // Overlaps with existing reservation
            Payment_Status__c = 'Pending'
        );
        
        // Test insertion
        Test.startTest();
        Database.SaveResult result = Database.insert(conflictingReservation, false);
        Test.stopTest();
        
        // Verify the reservation was not created due to the conflict
        System.assert(!result.isSuccess(), 'Conflicting reservation should not be created');
        
        // Verify the error message
        System.assertEquals(1, result.getErrors().size(), 'There should be one error');
        System.assertEquals('This room is already booked during the selected dates.', 
                           result.getErrors()[0].getMessage(), 
                           'Error message should indicate a booking conflict');
    }
    
    @isTest
    static void testExactDateConflict() {
        // Get the test room
        Room__c testRoom = [SELECT Id FROM Room__c WHERE Name = 'Test Room 101' LIMIT 1];
        
        // Get existing reservation data to create exact conflict
        Reservation__c existingReservation = [
            SELECT Check_In__c, Check_Out__c 
            FROM Reservation__c 
            WHERE Room__c = :testRoom.Id 
            LIMIT 1
        ];
        
        // Create a new reservation with exact same dates
        Reservation__c exactConflictReservation = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = existingReservation.Check_In__c,
            Check_Out__c = existingReservation.Check_Out__c,
            Payment_Status__c = 'Pending'
        );
        
        // Test insertion
        Test.startTest();
        Database.SaveResult result = Database.insert(exactConflictReservation, false);
        Test.stopTest();
        
        // Verify the reservation was not created due to the conflict
        System.assert(!result.isSuccess(), 'Exact date conflict reservation should not be created');
    }
    
    @isTest
    static void testEdgeOverlap() {
        // Get the test room
        Room__c testRoom = [SELECT Id FROM Room__c WHERE Name = 'Test Room 101' LIMIT 1];
        
        // Get existing reservation data
        Reservation__c existingReservation = [
            SELECT Check_In__c, Check_Out__c 
            FROM Reservation__c 
            WHERE Room__c = :testRoom.Id 
            LIMIT 1
        ];
        
        // Test case 1: New reservation's check-out is same as existing check-in (should not conflict)
        Reservation__c edgeCase1 = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = existingReservation.Check_In__c.addDays(-5),
            Check_Out__c = existingReservation.Check_In__c, // Ends exactly when the existing one starts
            Payment_Status__c = 'Pending'
        );
        
        // Test case 2: New reservation's check-in is same as existing check-out (should not conflict)
        Reservation__c edgeCase2 = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = existingReservation.Check_Out__c, // Starts exactly when the existing one ends
            Check_Out__c = existingReservation.Check_Out__c.addDays(5),
            Payment_Status__c = 'Pending'
        );
        
        // Test insertion for edge case 1
        Test.startTest();
        Database.SaveResult result1 = Database.insert(edgeCase1, false);
        
        // Test insertion for edge case 2
        Database.SaveResult result2 = Database.insert(edgeCase2, false);
        Test.stopTest();
        
        // Verify both reservations were created successfully (no conflict at the edges)
        System.assert(result1.isSuccess(), 'Edge case 1 should be allowed (check-out = existing check-in)');
        System.assert(result2.isSuccess(), 'Edge case 2 should be allowed (check-in = existing check-out)');
    }
    
    @isTest
    static void testMultipleRoomsNoConflict() {
        // Get both test rooms
        List<Room__c> testRooms = [SELECT Id FROM Room__c ORDER BY Name];
        Room__c room1 = testRooms[0];
        Room__c room2 = testRooms[1];
        
        // Get existing reservation for room1
        Reservation__c existingReservation = [
            SELECT Check_In__c, Check_Out__c 
            FROM Reservation__c 
            WHERE Room__c = :room1.Id 
            LIMIT 1
        ];
        
        // Create a new reservation for room2 with overlapping dates (should be allowed)
        Reservation__c newReservation = new Reservation__c(
            Room__c = room2.Id,
            Check_In__c = existingReservation.Check_In__c,
            Check_Out__c = existingReservation.Check_Out__c,
            Payment_Status__c = 'Pending'
        );
        
        // Test insertion
        Test.startTest();
        Database.SaveResult result = Database.insert(newReservation, false);
        Test.stopTest();
        
        // Verify the reservation was created successfully (different rooms can have overlapping dates)
        System.assert(result.isSuccess(), 'Different rooms can have overlapping reservation dates');
    }
    
    @isTest
    static void testUpdateReservationNoConflict() {
        // Get test room
        Room__c testRoom = [SELECT Id FROM Room__c WHERE Name = 'Test Room 101' LIMIT 1];
        
        // Create a new non-conflicting reservation first
        Reservation__c newReservation = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = Date.today().addDays(20),
            Check_Out__c = Date.today().addDays(25),
            Payment_Status__c = 'Pending'
        );
        insert newReservation;
        
        // Now update it (still no conflict)
        newReservation.Check_In__c = Date.today().addDays(21);
        newReservation.Check_Out__c = Date.today().addDays(26);
        
        // Test update
        Test.startTest();
        Database.SaveResult result = Database.update(newReservation, false);
        Test.stopTest();
        
        // Verify the update was successful
        System.assert(result.isSuccess(), 'Non-conflicting update should be successful');
    }
    
    @isTest
    static void testUpdateReservationWithConflict() {
        // Get test room
        Room__c testRoom = [SELECT Id FROM Room__c WHERE Name = 'Test Room 101' LIMIT 1];
        
        // Create a new non-conflicting reservation first
        Reservation__c newReservation = new Reservation__c(
            Room__c = testRoom.Id,
            Check_In__c = Date.today().addDays(20),
            Check_Out__c = Date.today().addDays(25),
            Payment_Status__c = 'Pending'
        );
        insert newReservation;
        
        // Get existing reservation data to create conflict
        Reservation__c existingReservation = [
            SELECT Check_In__c, Check_Out__c 
            FROM Reservation__c 
            WHERE Room__c = :testRoom.Id 
            AND Id != :newReservation.Id
            LIMIT 1
        ];
        
        // Now update to create a conflict
        newReservation.Check_In__c = existingReservation.Check_In__c;
        newReservation.Check_Out__c = existingReservation.Check_Out__c;
        
        // Test update
        Test.startTest();
        Database.SaveResult result = Database.update(newReservation, false);
        Test.stopTest();
        
        // Verify the update was not successful due to conflict
        System.assert(!result.isSuccess(), 'Update creating a conflict should fail');
        System.assertEquals('This room is already booked during the selected dates.', 
                           result.getErrors()[0].getMessage(), 
                           'Error message should indicate a booking conflict');
    }
    
    @isTest
    static void testNullRoomNoError() {
        // Create reservation with no room assigned
        Reservation__c noRoomReservation = new Reservation__c(
            Room__c = null,
            Check_In__c = Date.today().addDays(10),
            Check_Out__c = Date.today().addDays(15),
            Payment_Status__c = 'Pending'
        );
        
        // Test insertion
        Test.startTest();
        Database.SaveResult result = Database.insert(noRoomReservation, false);
        Test.stopTest();
        
        // Verify the reservation was created successfully
        System.assert(result.isSuccess(), 'Reservation with no room should be created successfully');
    }
    
    @isTest
    static void testBulkReservations() {
        // Get both test rooms
        List<Room__c> testRooms = [SELECT Id FROM Room__c ORDER BY Name];
        Room__c room1 = testRooms[0];
        Room__c room2 = testRooms[1];
        
        // Create a list of 200 reservations (100 for each room, with no conflicts)
        List<Reservation__c> bulkReservations = new List<Reservation__c>();
        
        for (Integer i = 0; i < 100; i++) {
            // Room 1 reservations (no conflicts with existing or each other)
            Reservation__c res1 = new Reservation__c(
                Room__c = room1.Id,
                Check_In__c = Date.today().addDays(30 + (i * 2)),
                Check_Out__c = Date.today().addDays(31 + (i * 2)),
                Payment_Status__c = 'Pending'
            );
            bulkReservations.add(res1);
            
            // Room 2 reservations (no conflicts)
            Reservation__c res2 = new Reservation__c(
                Room__c = room2.Id,
                Check_In__c = Date.today().addDays(30 + (i * 2)),
                Check_Out__c = Date.today().addDays(31 + (i * 2)),
                Payment_Status__c = 'Pending'
            );
            bulkReservations.add(res2);
        }
        
        // Test bulk insertion
        Test.startTest();
        List<Database.SaveResult> results = Database.insert(bulkReservations, false);
        Test.stopTest();
        
        // Count successful inserts
        Integer successCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            }
        }
        
        // Verify all 200 reservations were created successfully
        System.assertEquals(200, successCount, 'All 200 non-conflicting reservations should be created');
    }
}