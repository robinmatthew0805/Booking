@isTest
private class FeedbackServiceTest {
    
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
            Room_Type__c = 'Single',
            Check_In__c = DateTime.now().addDays(-7),
            Check_Out__c = DateTime.now().addDays(-5),
            Total_Cost__c = 200.00,
            Payment_Status__c = 'Paid',
            Status__c = 'Checked-out',
            PIN__c = '123456',
            Special_Requests__c = 'None'
        );
        insert testReservation;
    }
    
    @isTest
    static void testSaveFeedbackWithAllFields() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create feedback data
        Map<String, Object> feedbackData = new Map<String, Object>{
            'Reservation__c' => reservation.Id,
            'Guests__c' => 'John Doe, Jane Doe',
            'Stay_Date__c' => String.valueOf(Date.today().addDays(-6)),
            'Overall_Rating__c' => '5',
            'Room_Cleanliness_Rating__c' => '4',
            'Staff_Service_Rating__c' => '5',
            'Value_For_Money_Rating__c' => '4',
            'Would_Recommend__c' => true,
            'Comments__c' => 'Great stay, very comfortable room and excellent service.'
        };
        
        Test.startTest();
        Id feedbackId = FeedbackService.saveFeedback(feedbackData);
        Test.stopTest();
        
        // Verify feedback was created
        System.assertNotEquals(null, feedbackId, 'Feedback ID should not be null');
        
        // Query the feedback record to verify fields
        Feedback__c feedback = [
            SELECT Reservation__c, Guests__c, Stay_Date__c, Overall_Rating__c,
                   Room_Cleanliness_Rating__c, Staff_Service_Rating__c, 
                   Value_For_Money_Rating__c, Would_Recommend__c, Comments__c
            FROM Feedback__c
            WHERE Id = :feedbackId
        ];
        
        // Verify each field
        System.assertEquals(reservation.Id, feedback.Reservation__c, 'Reservation ID should match');
        System.assertEquals('John Doe, Jane Doe', feedback.Guests__c, 'Guests should match');
        System.assertEquals(Date.today().addDays(-6), feedback.Stay_Date__c, 'Stay date should match');
        System.assertEquals('5', feedback.Overall_Rating__c, 'Overall rating should match');
        System.assertEquals('4', feedback.Room_Cleanliness_Rating__c, 'Room cleanliness rating should match');
        System.assertEquals('5', feedback.Staff_Service_Rating__c, 'Staff service rating should match');
        System.assertEquals('4', feedback.Value_For_Money_Rating__c, 'Value for money rating should match');
        System.assertEquals(true, feedback.Would_Recommend__c, 'Would recommend should match');
        System.assertEquals('Great stay, very comfortable room and excellent service.', 
                           feedback.Comments__c, 'Comments should match');
    }
    
    @isTest
    static void testSaveFeedbackWithRequiredFieldsOnly() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create feedback data with only required fields
        Map<String, Object> feedbackData = new Map<String, Object>{
            'Reservation__c' => reservation.Id,
            'Overall_Rating__c' => '3'
        };
        
        Test.startTest();
        Id feedbackId = FeedbackService.saveFeedback(feedbackData);
        Test.stopTest();
        
        // Verify feedback was created
        System.assertNotEquals(null, feedbackId, 'Feedback ID should not be null');
        
        // Query the feedback record to verify fields
        Feedback__c feedback = [
            SELECT Reservation__c, Overall_Rating__c
            FROM Feedback__c
            WHERE Id = :feedbackId
        ];
        
        // Verify fields
        System.assertEquals(reservation.Id, feedback.Reservation__c, 'Reservation ID should match');
        System.assertEquals('3', feedback.Overall_Rating__c, 'Overall rating should match');
    }
    
    @isTest
    static void testSaveFeedbackWithNullFieldValues() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create feedback data with some null values
        Map<String, Object> feedbackData = new Map<String, Object>{
            'Reservation__c' => reservation.Id,
            'Overall_Rating__c' => '4',
            'Room_Cleanliness_Rating__c' => null,
            'Staff_Service_Rating__c' => null,
            'Comments__c' => null
        };
        
        Test.startTest();
        Id feedbackId = FeedbackService.saveFeedback(feedbackData);
        Test.stopTest();
        
        // Verify feedback was created
        System.assertNotEquals(null, feedbackId, 'Feedback ID should not be null');
        
        // Query the feedback record to verify fields
        Feedback__c feedback = [
            SELECT Reservation__c, Overall_Rating__c, Room_Cleanliness_Rating__c, 
                   Staff_Service_Rating__c, Comments__c
            FROM Feedback__c
            WHERE Id = :feedbackId
        ];
        
        // Verify fields
        System.assertEquals(reservation.Id, feedback.Reservation__c, 'Reservation ID should match');
        System.assertEquals('4', feedback.Overall_Rating__c, 'Overall rating should match');
        System.assertEquals(null, feedback.Room_Cleanliness_Rating__c, 'Room cleanliness rating should be null');
        System.assertEquals(null, feedback.Staff_Service_Rating__c, 'Staff service rating should be null');
        System.assertEquals(null, feedback.Comments__c, 'Comments should be null');
    }
    
    @isTest
    static void testSaveFeedbackWithInvalidReservation() {
        // Create feedback data with invalid reservation ID
        Map<String, Object> feedbackData = new Map<String, Object>{
            'Reservation__c' => 'a0000000000000001', // Invalid ID
            'Overall_Rating__c' => '5'
        };
        
        Test.startTest();
        try {
            Id feedbackId = FeedbackService.saveFeedback(feedbackData);
            System.assert(false, 'Exception should have been thrown for invalid reservation ID');
        } catch (AuraHandledException e) {
            // Expected exception
            System.assert(e.getMessage().contains('Error saving feedback'), 
                         'Exception message should mention error saving feedback');
        }
        Test.stopTest();
        
        // Verify no feedback was created
        List<Feedback__c> feedbackList = [SELECT Id FROM Feedback__c];
        System.assertEquals(0, feedbackList.size(), 'No feedback should have been created');
    }
    
    @isTest
    static void testSaveFeedbackWithInvalidDateFormat() {
        // Get test reservation
        Reservation__c reservation = [SELECT Id FROM Reservation__c LIMIT 1];
        
        // Create feedback data with invalid date format
        Map<String, Object> feedbackData = new Map<String, Object>{
            'Reservation__c' => reservation.Id,
            'Overall_Rating__c' => '5',
            'Stay_Date__c' => 'Invalid Date Format'
        };
        
        Test.startTest();
        try {
            Id feedbackId = FeedbackService.saveFeedback(feedbackData);
            System.assert(false, 'Exception should have been thrown for invalid date format');
        } catch (AuraHandledException e) {
            // Expected exception
            System.assert(e.getMessage().contains('Error saving feedback'), 
                         'Exception message should mention error saving feedback');
        }
        Test.stopTest();
        
        // Verify no feedback was created
        List<Feedback__c> feedbackList = [SELECT Id FROM Feedback__c];
        System.assertEquals(0, feedbackList.size(), 'No feedback should have been created');
    }
}