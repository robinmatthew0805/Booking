public class ServiceDepartmentMapper {
    public static void mapDepartments(List<Service__c> newRequests, Map<Id, Service__c> oldMap) {
        // Set to collect all the departments we need to query staff for
        Set<String> departmentsNeeded = new Set<String>();
        // Map to store service type to department mapping for each record
        Map<Id, String> requestToDepartmentMap = new Map<Id, String>();
        
        // First pass: determine departments based on service types
        for (Service__c request : newRequests) {
            // Get the old version of the record for updates
            Service__c oldRequest = (oldMap != null) ? oldMap.get(request.Id) : null;
            
            // Check if Service Type has changed or is being set for the first time
            if (oldMap == null || (oldRequest != null && request.Service_Type__c != oldRequest.Service_Type__c)) {
                // Only proceed if Service Type is not empty
                if (request.Service_Type__c != null) {
                    // Map Service Type to appropriate Department
                    String department = getDepartmentForServiceType(request.Service_Type__c);
                    
                    // Store the department for this request
                    requestToDepartmentMap.put(request.Id, department);
                    
                    // Add to our set of departments to query
                    if (department != '--None--') {
                        departmentsNeeded.add(department);
                    }
                }
            }
        }
        
        // If we have departments to query, fetch available staff
        if (!departmentsNeeded.isEmpty()) {
            // Query for available staff members by department
            Map<String, Staff__c> departmentToStaffMap = getAvailableStaffByDepartment(departmentsNeeded);
            
            // Second pass: assign staff based on department
            for (Service__c request : newRequests) {
                String department = requestToDepartmentMap.get(request.Id);
                if (department != null && department != '--None--') {
                    Staff__c availableStaff = departmentToStaffMap.get(department);
                    if (availableStaff != null) {
                        request.Assigned_Staff__c = availableStaff.Id;
                    }
                }
            }
        }
    }

    private static Map<String, Staff__c> getAvailableStaffByDepartment(Set<String> departments) {
        Map<String, Staff__c> departmentToStaffMap = new Map<String, Staff__c>();
        
        // Query for available staff in the required departments
        List<Staff__c> availableStaff = [
            SELECT Id, Name, Department__c, Current_Status__c
            FROM Staff__c
            WHERE Department__c IN :departments
            AND Current_Status__c = 'Available'
            LIMIT 1000
        ];
        
        // Group staff by department and take the first available one for each department
        Map<String, List<Staff__c>> staffByDepartment = new Map<String, List<Staff__c>>();
        
        for (Staff__c staff : availableStaff) {
            if (!staffByDepartment.containsKey(staff.Department__c)) {
                staffByDepartment.put(staff.Department__c, new List<Staff__c>());
            }
            staffByDepartment.get(staff.Department__c).add(staff);
        }
        
        // For each department, add the first available staff member to our map
        for (String department : departments) {
            if (staffByDepartment.containsKey(department) && !staffByDepartment.get(department).isEmpty()) {
                // Get the first available staff for this department
                departmentToStaffMap.put(department, staffByDepartment.get(department)[0]);
            }
        }
        
        return departmentToStaffMap;
    }

    private static String getDepartmentForServiceType(String serviceType) {
        // Front Office services
        if (serviceType == 'Room Key Replacement' || 
            serviceType == 'Luggage Assistance' ||
            serviceType == 'Express Check-out' ||
            serviceType == 'Late Check-out Request' ||
            serviceType == 'Transportation Arrangement') {
            return 'Front Office';
        }
        
        // Housekeeping services
        else if (serviceType == 'Room Cleaning' ||
                serviceType == 'Turndown Service' ||
                serviceType == 'Extra Towels' ||
                serviceType == 'Laundry Service' ||
                serviceType == 'Extra Amenities') {
            return 'Housekeeping';
        }
        
        // Maintenance services
        else if (serviceType == 'Air Conditioning Issue' ||
                serviceType == 'Plumbing Issue' ||
                serviceType == 'Electrical Issue' ||
                serviceType == 'TV/Entertainment System Issue') {
            return 'Maintenance';
        }
        
        // Food & Beverage services
        else if (serviceType == 'Room Service' ||
                serviceType == 'Dining Reservation' ||
                serviceType == 'Special Dietary Request' ||
                serviceType == 'Mini Bar Refill') {
            return 'Food & Beverage';
        }
        
        // Additional Services - Map to appropriate departments
        else if (serviceType == 'WiFi Assistance') {
            return 'Maintenance'; // IT could be separate, but assuming Maintenance handles IT
        }
        else if (serviceType == 'Spa Appointment') {
            return 'Front Office'; // Assuming Front Office handles spa bookings
        }
        else if (serviceType == 'Wake-up Call') {
            return 'Front Office';
        }
        else if (serviceType == 'Special Occasion Setup') {
            return 'Housekeeping'; // Assuming Housekeeping handles room setups
        }
        
        // Default return if no match is found
        return '--None--';
    }
}