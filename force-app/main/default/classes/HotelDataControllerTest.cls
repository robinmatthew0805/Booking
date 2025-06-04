/**
 * Simplified test class for HotelDataController
 */
@isTest
private class HotelDataControllerTest {
    
    // Setup test data
    @TestSetup
    static void makeData(){
        // Create test Contact for Guest
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Guest',
            Email = 'test.guest@example.com',
            Phone = '555-1234'
        );
        insert testContact;
        
        // Create test Room
        Room__c testRoom = new Room__c(
            Room_Number__c = 101,
            Room_Type__c = 'Standard',
            Price_Per_Night__c = 100.00,
            Features__c = 'WiFi, TV',
            Floor__c = 1,
            Status__c = 'Available'
        );
        insert testRoom;
        
        // Create upcoming reservation
        Reservation__c upcomingReservation = new Reservation__c(
            Guest_Name__c = testContact.Id,
            Room__c = testRoom.Id,
            Check_In__c = Datetime.now().addDays(2),
            Check_out__c = Datetime.now().addDays(5),
            Room_Type__c = 'Standard',
            Status__c = 'Confirmed',
            Payment_Status__c = 'Paid'
        );
        insert upcomingReservation;
        
        // Create today's check-in reservation
        Reservation__c todayCheckIn = new Reservation__c(
            Guest_Name__c = testContact.Id,
            Room__c = testRoom.Id,
            Check_In__c = Datetime.now().addHours(2), // Today but a few hours later
            Check_out__c = Datetime.now().addDays(3),
            Room_Type__c = 'Standard',
            Status__c = 'Confirmed',
            Payment_Status__c = 'Paid'
        );
        insert todayCheckIn;
        
        // Create today's check-out reservation
        Reservation__c todayCheckOut = new Reservation__c(
            Guest_Name__c = testContact.Id,
            Room__c = testRoom.Id,
            Check_In__c = Datetime.now().addDays(-3),
            Check_out__c = Datetime.now().addHours(2), // Today but a few hours later
            Room_Type__c = 'Standard',
            Status__c = 'Checked-in',
            Payment_Status__c = 'Paid'
        );
        insert todayCheckOut;
        
        // Create test Promotion
        Promo_and_Advertisement__c testPromo = new Promo_and_Advertisement__c(
            Promo_Name__c = 'Summer Special',
            Target_Customers__c = 'All Guests',
            Applicable_Room_Types__c = 'All',
            Discount_Percentage__c = 10,
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(30),
            Additional_Details__c = 'Special summer promotion'
        );
        insert testPromo;
    }
    
    /**
     * Test getting upcoming reservations
     */
    @isTest
    static void testGetUpcomingReservations() {
        Test.startTest();
        List<Reservation__c> upcomingReservations = HotelDataController.getUpcomingReservations();
        Test.stopTest();
        
        System.assertNotEquals(null, upcomingReservations, 'Upcoming reservations should not be null');
        System.assertNotEquals(0, upcomingReservations.size(), 'Should return at least one upcoming reservation');
        
        // Verify the booking number of the upcoming reservation
        Boolean foundUpcoming = false;
        for(Reservation__c res : upcomingReservations) {
            if(res.Booking_Number__c == 'BK001') {
                foundUpcoming = true;
                break;
            }
        }
        System.assert(foundUpcoming, 'Should find the upcoming reservation');
    }
    
    /**
     * Test getting today's check-ins
     */
    @isTest
    static void testGetTodayCheckIns() {
        Test.startTest();
        List<Reservation__c> todayCheckIns = HotelDataController.getTodayCheckIns();
        Test.stopTest();
        
        System.assertNotEquals(null, todayCheckIns, 'Today check-ins should not be null');
        
        // Set specific date for testing
        for(Reservation__c res : todayCheckIns) {
            System.debug('Check-in date: ' + res.Check_In__c);
        }
        
        // Check at least one record has the expected booking number
        Boolean foundCheckIn = false;
        for(Reservation__c res : todayCheckIns) {
            if(res.Booking_Number__c == 'BK002') {
                foundCheckIn = true;
                break;
            }
        }
        System.assert(foundCheckIn, 'Should find today\'s check-in reservation');
    }
    
    /**
     * Test getting today's check-outs
     */
    @isTest
    static void testGetTodayCheckOuts() {
        Test.startTest();
        List<Reservation__c> todayCheckOuts = HotelDataController.getTodayCheckOuts();
        Test.stopTest();
        
        System.assertNotEquals(null, todayCheckOuts, 'Today check-outs should not be null');
        
        // Check at least one record has the expected booking number
        Boolean foundCheckOut = false;
        for(Reservation__c res : todayCheckOuts) {
            if(res.Booking_Number__c == 'BK003') {
                foundCheckOut = true;
                break;
            }
        }
        System.assert(foundCheckOut, 'Should find today\'s check-out reservation');
    }
    
    /**
     * Test searching for reservations
     */
    @isTest
    static void testSearchReservations() {
        Date fromDate = Date.today();
        Date toDate = Date.today().addDays(7);
        
        Test.startTest();
        List<Reservation__c> searchResults = HotelDataController.searchReservations('BK001', fromDate, toDate);
        Test.stopTest();
        
        System.assertNotEquals(null, searchResults, 'Search results should not be null');
        System.assertNotEquals(0, searchResults.size(), 'Should return at least one search result');
        
        // Verify the search result contains the expected reservation
        Boolean foundReservation = false;
        for(Reservation__c res : searchResults) {
            if(res.Booking_Number__c == 'BK001') {
                foundReservation = true;
                break;
            }
        }
        System.assert(foundReservation, 'Should find the reservation in search results');
    }
    
    /**
     * Test updating reservation status
     */
    @isTest
    static void testUpdateReservationStatus() {
        // Get the ID of an existing reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c WHERE Booking_Number__c = 'BK001' LIMIT 1];
        
        Test.startTest();
        Boolean result = HotelDataController.updateReservationStatus(reservation.Id, 'Checked-in');
        Test.stopTest();
        
        // Verify the result
        System.assertEquals(true, result, 'Status update should be successful');
        
        // Verify the reservation status was actually updated
        Reservation__c updatedReservation = [SELECT Status__c FROM Reservation__c WHERE Id = :reservation.Id LIMIT 1];
        System.assertEquals('Checked-in', updatedReservation.Status__c, 'Reservation status should be updated');
    }
    
    /**
     * Test searching for guests
     */
    @isTest
    static void testSearchGuests() {
        Test.startTest();
        List<Contact> guests = HotelDataController.searchGuests('Test');
        Test.stopTest();
        
        System.assertNotEquals(null, guests, 'Guest search results should not be null');
        System.assertNotEquals(0, guests.size(), 'Should return at least one guest');
        
        // Verify we found the expected guest
        Boolean foundGuest = false;
        for(Contact guest : guests) {
            if(guest.FirstName == 'Test' && guest.LastName == 'Guest') {
                foundGuest = true;
                break;
            }
        }
        System.assert(foundGuest, 'Should find the test guest');
    }
    
    /**
     * Test getting promotions
     */
    @isTest
    static void testGetPromotions() {
        Test.startTest();
        List<Promo_and_Advertisement__c> promotions = HotelDataController.getPromotions();
        Test.stopTest();
        
        System.assertNotEquals(null, promotions, 'Promotions should not be null');
        System.assertNotEquals(0, promotions.size(), 'Should return at least one promotion');
        
        // Verify we found the expected promotion
        Boolean foundPromo = false;
        for(Promo_and_Advertisement__c promo : promotions) {
            if(promo.Promo_Name__c == 'Summer Special') {
                foundPromo = true;
                break;
            }
        }
        System.assert(foundPromo, 'Should find the test promotion');
    }
    
    /**
     * Test searching for promotions
     */
    @isTest
    static void testSearchPromotions() {
        Date activeDate = Date.today();
        
        Test.startTest();
        List<Promo_and_Advertisement__c> searchResults = HotelDataController.searchPromotions('Summer', null, activeDate);
        Test.stopTest();
        
        System.assertNotEquals(null, searchResults, 'Promotion search results should not be null');
        
        // Note: This test might fail if searchPromotions has SQL syntax issues with field names
        // since we're testing against a stub implementation of the object
    }
}