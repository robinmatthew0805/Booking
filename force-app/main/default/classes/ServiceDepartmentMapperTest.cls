@isTest
private class ServiceDepartmentMapperTest {
    
    // Test setup method to create test data
    @testSetup
    static void setupTestData() {
        // Create staff members for each department
        List<Staff__c> staffToInsert = new List<Staff__c>();
        
        Staff__c frontOfficeStaff = new Staff__c(
            Department__c = 'Front Office',
            Current_Status__c = 'Available'
        );
        staffToInsert.add(frontOfficeStaff);
        
        Staff__c housekeepingStaff = new Staff__c(
            Department__c = 'Housekeeping',
            Current_Status__c = 'Available'
        );
        staffToInsert.add(housekeepingStaff);
        
        Staff__c maintenanceStaff = new Staff__c(
            Department__c = 'Maintenance',
            Current_Status__c = 'Available'
        );
        staffToInsert.add(maintenanceStaff);
        
        Staff__c foodBeverageStaff = new Staff__c(
            Department__c = 'Food & Beverage',
            Current_Status__c = 'Available'
        );
        staffToInsert.add(foodBeverageStaff);
        
        // Add an unavailable staff member to test availability logic
        Staff__c unavailableStaff = new Staff__c(
            Department__c = 'Front Office',
            Current_Status__c = 'Unavailable'
        );
        staffToInsert.add(unavailableStaff);
        
        insert staffToInsert;
    }
    
    @isTest
    static void testInsertServiceRequests() {
        // Create test service requests for different departments
        List<Service__c> serviceRequests = new List<Service__c>();
        
        Service__c frontOfficeRequest = new Service__c(
            Service_Type__c = 'Room Key Replacement'
        );
        serviceRequests.add(frontOfficeRequest);
        
        Service__c housekeepingRequest = new Service__c(
            Service_Type__c = 'Room Cleaning'
        );
        serviceRequests.add(housekeepingRequest);
        
        Service__c maintenanceRequest = new Service__c(
            Service_Type__c = 'Air Conditioning Issue'
        );
        serviceRequests.add(maintenanceRequest);
        
        Service__c foodBeverageRequest = new Service__c(
            Service_Type__c = 'Room Service'
        );
        serviceRequests.add(foodBeverageRequest);
        
        // Insert the records which should trigger the mapper
        Test.startTest();
        insert serviceRequests;
        Test.stopTest();
        
        // Query the records to verify staff assignments
        Map<Id, Service__c> updatedRequests = new Map<Id, Service__c>([
            SELECT Id, Service_Type__c, Assigned_Staff__c
            FROM Service__c
            WHERE Id IN :serviceRequests
        ]);
        
        // Get staff records to validate assignments
        Map<String, Id> departmentToStaffIdMap = new Map<String, Id>();
        for (Staff__c staff : [SELECT Id, Department__c FROM Staff__c WHERE Current_Status__c = 'Available']) {
            departmentToStaffIdMap.put(staff.Department__c, staff.Id);
        }
        
        // Verify each request has the correct staff assigned
        System.assertEquals(departmentToStaffIdMap.get('Front Office'), 
                            updatedRequests.get(frontOfficeRequest.Id).Assigned_Staff__c,
                            'Front Office request should be assigned to Front Office staff');
        
        System.assertEquals(departmentToStaffIdMap.get('Housekeeping'), 
                            updatedRequests.get(housekeepingRequest.Id).Assigned_Staff__c,
                            'Housekeeping request should be assigned to Housekeeping staff');
        
        System.assertEquals(departmentToStaffIdMap.get('Maintenance'), 
                            updatedRequests.get(maintenanceRequest.Id).Assigned_Staff__c,
                            'Maintenance request should be assigned to Maintenance staff');
        
        System.assertEquals(departmentToStaffIdMap.get('Food & Beverage'), 
                            updatedRequests.get(foodBeverageRequest.Id).Assigned_Staff__c,
                            'Food & Beverage request should be assigned to Food & Beverage staff');
    }
    
    @isTest
    static void testUpdateServiceType() {
        // Create a service request with initial service type
        Service__c serviceRequest = new Service__c(
            Service_Type__c = 'Room Key Replacement' // Front Office
        );
        
        insert serviceRequest;
        
        // Get staff IDs for verification
        Map<String, Id> departmentToStaffIdMap = new Map<String, Id>();
        for (Staff__c staff : [SELECT Id, Department__c FROM Staff__c WHERE Current_Status__c = 'Available']) {
            departmentToStaffIdMap.put(staff.Department__c, staff.Id);
        }
        
        // Update the service type to a different department
        Test.startTest();
        serviceRequest.Service_Type__c = 'Room Cleaning'; // Housekeeping
        update serviceRequest;
        Test.stopTest();
        
        // Query the updated request
        Service__c updatedRequest = [
            SELECT Id, Service_Type__c, Assigned_Staff__c
            FROM Service__c
            WHERE Id = :serviceRequest.Id
        ];
        
        // Verify the staff assignment was updated to the new department
        System.assertEquals(departmentToStaffIdMap.get('Housekeeping'), 
                            updatedRequest.Assigned_Staff__c,
                            'After update, request should be assigned to Housekeeping staff');
    }
    
    @isTest
    static void testNoAvailableStaff() {
        // Make all staff unavailable first
        List<Staff__c> allStaff = [SELECT Id FROM Staff__c];
        for (Staff__c staff : allStaff) {
            staff.Current_Status__c = 'Unavailable';
        }
        update allStaff;
        
        // Create a new service request
        Service__c serviceRequest = new Service__c(
            Service_Type__c = 'Room Key Replacement' // Front Office
        );
        
        // Insert the record
        Test.startTest();
        insert serviceRequest;
        Test.stopTest();
        
        // Query the record to verify no staff was assigned
        Service__c updatedRequest = [
            SELECT Id, Assigned_Staff__c
            FROM Service__c
            WHERE Id = :serviceRequest.Id
        ];
        
        // Verify no staff was assigned
        System.assertEquals(null, updatedRequest.Assigned_Staff__c,
                           'No staff should be assigned when no staff is available');
    }
    
    @isTest
    static void testBulkOperation() {
        // Create 200 service requests (to test bulk processing)
        List<Service__c> bulkRequests = new List<Service__c>();
        
        // Create 50 of each type
        for (Integer i = 0; i < 50; i++) {
            bulkRequests.add(new Service__c(Service_Type__c = 'Room Key Replacement')); // Front Office
            bulkRequests.add(new Service__c(Service_Type__c = 'Room Cleaning')); // Housekeeping
            bulkRequests.add(new Service__c(Service_Type__c = 'Air Conditioning Issue')); // Maintenance
            bulkRequests.add(new Service__c(Service_Type__c = 'Room Service')); // Food & Beverage
        }
        
        // Insert the bulk records
        Test.startTest();
        insert bulkRequests;
        Test.stopTest();
        
        // Query records by department to verify assignments
        Map<String, Integer> typeCountMap = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT Service_Type__c, COUNT(Id) recordCount
            FROM Service__c
            WHERE Id IN :bulkRequests
            GROUP BY Service_Type__c
        ]) {
            String serviceType = (String)ar.get('Service_Type__c');
            Integer count = (Integer)ar.get('recordCount');
            typeCountMap.put(serviceType, count);
        }
        
        // Verify counts
        System.assertEquals(50, typeCountMap.get('Room Key Replacement'),
                           '50 Room Key Replacement requests should be processed');
        System.assertEquals(50, typeCountMap.get('Room Cleaning'),
                           '50 Room Cleaning requests should be processed');
        System.assertEquals(50, typeCountMap.get('Air Conditioning Issue'),
                           '50 Air Conditioning Issue requests should be processed');
        System.assertEquals(50, typeCountMap.get('Room Service'),
                           '50 Room Service requests should be processed');
        
        // Verify all have staff assigned
        Integer assignedCount = [
            SELECT COUNT()
            FROM Service__c
            WHERE Id IN :bulkRequests
            AND Assigned_Staff__c != null
        ];
        
        System.assertEquals(bulkRequests.size(), assignedCount,
                           'All bulk requests should have staff assigned');
    }
    
    @isTest
    static void testNonExistentServiceType() {
        // Create a service with a service type that doesn't match any defined mappings
        Service__c invalidRequest = new Service__c(
            Service_Type__c = 'Invalid Service Type'
        );
        
        // Insert the record
        Test.startTest();
        insert invalidRequest;
        Test.stopTest();
        
        // Query the record to verify no staff was assigned
        Service__c updatedRequest = [
            SELECT Id, Assigned_Staff__c
            FROM Service__c
            WHERE Id = :invalidRequest.Id
        ];
        
        // Verify no staff was assigned due to no matching department
        System.assertEquals(null, updatedRequest.Assigned_Staff__c,
                           'No staff should be assigned for an invalid service type');
    }
    
    @isTest
    static void testAllServiceTypes() {
        // Test all service types defined in the mapper class
        List<String> allServiceTypes = new List<String>{
            // Front Office
            'Room Key Replacement', 'Luggage Assistance', 'Express Check-out', 
            'Late Check-out Request', 'Transportation Arrangement', 'Spa Appointment', 'Wake-up Call',
            
            // Housekeeping
            'Room Cleaning', 'Turndown Service', 'Extra Towels', 'Laundry Service', 
            'Extra Amenities', 'Special Occasion Setup',
            
            // Maintenance
            'Air Conditioning Issue', 'Plumbing Issue', 'Electrical Issue', 
            'TV/Entertainment System Issue', 'WiFi Assistance',
            
            // Food & Beverage
            'Room Service', 'Dining Reservation', 'Special Dietary Request', 'Mini Bar Refill'
        };
        
        // Create requests for all service types
        List<Service__c> allTypeRequests = new List<Service__c>();
        
        for (String serviceType : allServiceTypes) {
            allTypeRequests.add(new Service__c(Service_Type__c = serviceType));
        }
        
        // Insert all requests
        Test.startTest();
        insert allTypeRequests;
        Test.stopTest();
        
        // Query the results and group by service type
        Map<String, Service__c> typeToRequestMap = new Map<String, Service__c>();
        for (Service__c req : [SELECT Id, Service_Type__c, Assigned_Staff__c FROM Service__c WHERE Id IN :allTypeRequests]) {
            typeToRequestMap.put(req.Service_Type__c, req);
        }
        
        // Get staff mapping
        Map<String, Id> departmentToStaffIdMap = new Map<String, Id>();
        for (Staff__c staff : [SELECT Id, Department__c FROM Staff__c WHERE Current_Status__c = 'Available']) {
            departmentToStaffIdMap.put(staff.Department__c, staff.Id);
        }
        
        // Verify correct assignments for each service type
        // Front Office service types
        List<String> frontOfficeTypes = new List<String>{
            'Room Key Replacement', 'Luggage Assistance', 'Express Check-out', 
            'Late Check-out Request', 'Transportation Arrangement', 'Spa Appointment', 'Wake-up Call'
        };
        
        for (String type : frontOfficeTypes) {
            System.assertEquals(departmentToStaffIdMap.get('Front Office'), 
                               typeToRequestMap.get(type).Assigned_Staff__c,
                               type + ' should be assigned to Front Office staff');
        }
        
        // Housekeeping service types
        List<String> housekeepingTypes = new List<String>{
            'Room Cleaning', 'Turndown Service', 'Extra Towels', 'Laundry Service', 
            'Extra Amenities', 'Special Occasion Setup'
        };
        
        for (String type : housekeepingTypes) {
            System.assertEquals(departmentToStaffIdMap.get('Housekeeping'), 
                               typeToRequestMap.get(type).Assigned_Staff__c,
                               type + ' should be assigned to Housekeeping staff');
        }
        
        // Maintenance service types
        List<String> maintenanceTypes = new List<String>{
            'Air Conditioning Issue', 'Plumbing Issue', 'Electrical Issue', 
            'TV/Entertainment System Issue', 'WiFi Assistance'
        };
        
        for (String type : maintenanceTypes) {
            System.assertEquals(departmentToStaffIdMap.get('Maintenance'), 
                               typeToRequestMap.get(type).Assigned_Staff__c,
                               type + ' should be assigned to Maintenance staff');
        }
        
        // Food & Beverage service types
        List<String> foodBeverageTypes = new List<String>{
            'Room Service', 'Dining Reservation', 'Special Dietary Request', 'Mini Bar Refill'
        };
        
        for (String type : foodBeverageTypes) {
            System.assertEquals(departmentToStaffIdMap.get('Food & Beverage'), 
                               typeToRequestMap.get(type).Assigned_Staff__c,
                               type + ' should be assigned to Food & Beverage staff');
        }
    }
}