@isTest
private class CheckoutStatusBatchClassTest {
    
    @testSetup
    static void setupTestData() {
        // Create test guests
        List<Contact> guests = new List<Contact>();
        for(Integer i = 0; i < 5; i++) {
            Contact guest = new Contact(
                FirstName = 'Test',
                LastName = 'Guest ' + i,
                Email = 'testguest' + i + '@example.com'
            );
            guests.add(guest);
        }
        insert guests;
        
        // Create test rooms
        List<Room__c> rooms = new List<Room__c>();
        for(Integer i = 0; i < 5; i++) {
            Room__c room = new Room__c(
                Name = 'Test Room ' + i,
                Status__c = 'Occupied',
                Cleaning_Status__c = 'Clean'
            );
            rooms.add(room);
        }
        insert rooms;
        
        // Create test reservations
        List<Reservation__c> reservations = new List<Reservation__c>();
        
        // Past checkout date, not checked out (should be updated)
        Reservation__c pastRes1 = new Reservation__c(
            Status__c = 'Active',
            Room__c = rooms[0].Id,
            Guest_Name__c = guests[0].Id,
            CheckOut_Date__c = Date.today().addDays(-2)
        );
        reservations.add(pastRes1);
        
        // Past checkout date, not checked out (should be updated)
        Reservation__c pastRes2 = new Reservation__c(
            Status__c = 'Active',
            Room__c = rooms[1].Id,
            Guest_Name__c = guests[1].Id,
            CheckOut_Date__c = Date.today().addDays(-1)
        );
        reservations.add(pastRes2);
        
        // Today's checkout date, not checked out (should be updated)
        Reservation__c todayRes = new Reservation__c(
            Status__c = 'Active',
            Room__c = rooms[2].Id,
            Guest_Name__c = guests[2].Id,
            CheckOut_Date__c = Date.today()
        );
        reservations.add(todayRes);
        
        // Past checkout date, already checked out (should not be updated)
        Reservation__c checkedOutRes = new Reservation__c(
            Status__c = 'Checked Out',
            Room__c = rooms[3].Id,
            Guest_Name__c = guests[3].Id,
            CheckOut_Date__c = Date.today().addDays(-3)
        );
        reservations.add(checkedOutRes);
        
        // Future checkout date (should not be updated)
        Reservation__c futureRes = new Reservation__c(
            Status__c = 'Active',
            Room__c = rooms[4].Id,
            Guest_Name__c = guests[4].Id,
            CheckOut_Date__c = Date.today().addDays(2)
        );
        reservations.add(futureRes);
        
        insert reservations;
    }
    
    @isTest
    static void testBatchExecution() {
        // Start test
        Test.startTest();
        
        // Execute the batch
        Database.executeBatch(new CheckoutStatusBatchClass());
        
        // Stop test to force async processes to complete
        Test.stopTest();
        
        // Verify reservations were updated correctly
        List<Reservation__c> updatedReservations = [SELECT Id, Status__c, Room__c, CheckOut_Date__c 
                                                   FROM Reservation__c];
        
        // Count how many were updated
        Integer checkedOutCount = 0;
        for(Reservation__c res : updatedReservations) {
            if(res.Status__c == 'Checked Out') {
                checkedOutCount++;
            }
        }
        
        // We expect 4 reservations to be in 'Checked Out' status
        // (3 that were updated + 1 that was already checked out)
        System.assertEquals(4, checkedOutCount, 'Expected 4 reservations to be checked out');
        
        // Verify rooms were updated correctly
        List<Room__c> updatedRooms = [SELECT Id, Status__c, Cleaning_Status__c 
                                     FROM Room__c];
        
        // Count rooms in maintenance status
        Integer maintenanceCount = 0;
        Integer needsCleaningCount = 0;
        for(Room__c room : updatedRooms) {
            if(room.Status__c == 'Maintenance') {
                maintenanceCount++;
            }
            if(room.Cleaning_Status__c == 'Needs Cleaning') {
                needsCleaningCount++;
            }
        }
        
        // We expect 3 rooms to be in maintenance status and needs cleaning
        System.assertEquals(3, maintenanceCount, 'Expected 3 rooms to be in maintenance status');
        System.assertEquals(3, needsCleaningCount, 'Expected 3 rooms to need cleaning');
        
        // Verify logs were created
        List<Log__c> logs = [SELECT Id, Action__c, Reservation__c, Guest__c 
                            FROM Log__c 
                            WHERE Action__c = 'Auto Checkout'];
        
        // We expect 3 logs to be created (one for each updated reservation)
        System.assertEquals(3, logs.size(), 'Expected 3 logs to be created');
        
        // Verify each log has a reservation
        for(Log__c log : logs) {
            System.assertNotEquals(null, log.Reservation__c, 'Expected log to be linked to a reservation');
            System.assertNotEquals(null, log.Guest__c, 'Expected log to be linked to a guest');
        }
    }
    
    @isTest
    static void testNoReservationsToUpdate() {
        // Delete all reservations with past or current checkout dates
        List<Reservation__c> reservationsToDelete = [SELECT Id 
                                                   FROM Reservation__c 
                                                   WHERE CheckOut_Date__c <= :Date.today()
                                                   AND Status__c != 'Checked Out'];
        delete reservationsToDelete;
        
        // Start test
        Test.startTest();
        
        // Execute the batch
        CheckoutStatusBatchClass batchClass = new CheckoutStatusBatchClass();
        Database.executeBatch(batchClass);
        
        // Stop test to force async processes to complete
        Test.stopTest();
        
        // Verify no logs were created
        List<Log__c> logs = [SELECT Id FROM Log__c WHERE Action__c = 'Auto Checkout'];
        System.assertEquals(0, logs.size(), 'Expected no logs to be created');
        
        // Verify count is 0
        System.assertEquals(0, batchClass.count, 'Expected count to be 0');
    }
    
    // @isTest
    // static void testScheduler() {
    //     // Create the scheduler class
    //     CheckoutStatusSchedule scheduler = new CheckoutStatusSchedule();
        
    //     // Start test
    //     Test.startTest();
        
    //     // Schedule the job
    //     String jobId = System.schedule('Test Checkout Status Batch', 
    //                                  '0 0 0 * * ?', 
    //                                  scheduler);
        
    //     // Stop test
    //     Test.stopTest();
        
    //     // Verify job was scheduled
    //     List<CronTrigger> cronTriggers = [SELECT Id, CronExpression 
    //                                      FROM CronTrigger 
    //                                      WHERE Id = :jobId];
        
    //     System.assertEquals(1, cronTriggers.size(), 'Expected job to be scheduled');
    //     System.assertEquals('0 0 0 * * ?', cronTriggers[0].CronExpression, 'Expected correct cron expression');
    // }
}