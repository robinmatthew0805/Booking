trigger ServiceRequestDepartmentMapping on Service__c (before insert, before update) {
    if (Trigger.isBefore) {
        ServiceDepartmentMapper.mapDepartments(Trigger.new, Trigger.oldMap);
    }
}