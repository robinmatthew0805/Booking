@isTest
private class PromoServiceTest {
    
    // Setup test data
    @TestSetup
    static void makeData() {
        // Create contact for promo owner
        Contact ownerContact = new Contact(
            FirstName = 'Robin',
            LastName = 'Matthew Medina',
            Email = 'robin.medina@example.com',
            Phone = '555-5678'
        );
        insert ownerContact;
        
        // Create active promotion (current dates)
        Promo_and_Advertisement__c activePromo = new Promo_and_Advertisement__c(
            Promo_Name__c = 'Active Promo',
            Owner__c = ownerContact.Id,
            Target_Customers__c = 'New Guests',
            Discount_Percentage__c = 15,
            Applicable_Room_Types__c = 'Suite;Single',
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(5),
            Additional_Details__c = 'Current active promotion'
        );
        
        // Create future promotion
        Promo_and_Advertisement__c futurePromo = new Promo_and_Advertisement__c(
            Promo_Name__c = 'Future Promo',
            Owner__c = ownerContact.Id,
            Target_Customers__c = 'New Guests',
            Discount_Percentage__c = 20,
            Applicable_Room_Types__c = 'Single;Suite',
            Start_Date__c = Date.today().addDays(10),
            End_Date__c = Date.today().addDays(20),
            Additional_Details__c = 'Future promotion'
        );
        
        // Create expired promotion
        Promo_and_Advertisement__c expiredPromo = new Promo_and_Advertisement__c(
            Promo_Name__c = 'Expired Promo',
            Owner__c = ownerContact.Id,
            Target_Customers__c = 'Loyalty Members',
            Discount_Percentage__c = 10,
            Applicable_Room_Types__c = 'Suite;Single',
            Start_Date__c = Date.today().addDays(-20),
            End_Date__c = Date.today().addDays(-10),
            Additional_Details__c = 'Expired promotion'
        );
        
        // Insert all promotions
        insert new List<Promo_and_Advertisement__c>{activePromo, futurePromo, expiredPromo};
    }
    
    /**
     * Test getActivePromotions method
     */
    @isTest
    static void testGetActivePromotions() {
        // Call the method
        Test.startTest();
        List<Promo_and_Advertisement__c> activePromos = PromoService.getActivePromotions();
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, activePromos, 'Active promotions should not be null');
        System.assertEquals(1, activePromos.size(), 'Should return exactly one active promotion');
        
        // Verify the correct promotion was returned
        Promo_and_Advertisement__c promo = activePromos[0];
        System.assertEquals('Active Promo', promo.Promo_Name__c, 'Should return the active promotion');
        System.assertEquals(15, promo.Discount_Percentage__c, 'Discount percentage should be 15');
    }
    
    /**
     * Test getRoomTypes method
     */
    @isTest
    static void testGetRoomTypes() {
        // Call the method
        Test.startTest();
        List<String> roomTypes = PromoService.getRoomTypes();
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, roomTypes, 'Room types should not be null');
        System.assertEquals(6, roomTypes.size(), 'Should return 6 room types');
        
        // Verify specific room types
        Set<String> expectedRoomTypes = new Set<String>{
            'Single', 'Double', 'Suite', 'Premium'
        };
        
        for (String roomType : roomTypes) {
            System.assert(expectedRoomTypes.contains(roomType), 
                         'Room type "' + roomType + '" should be in the expected room types');
        }
    }
}