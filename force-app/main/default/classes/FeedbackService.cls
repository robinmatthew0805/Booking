public without sharing class FeedbackService {
    public static Id saveFeedback(Map<String, Object> feedbackData) {
        try {
            // Create a new feedback record
            Feedback__c feedback = new Feedback__c();
            
            // Map the data from the input map to the feedback object
            if (feedbackData.containsKey('Reservation__c') && feedbackData.get('Reservation__c') != null) {
                feedback.Reservation__c = (String)feedbackData.get('Reservation__c');
            }
            
            if (feedbackData.containsKey('Guests__c') && feedbackData.get('Guests__c') != null) {
                feedback.Guests__c = (String)feedbackData.get('Guests__c');
            }
            
            if (feedbackData.containsKey('Stay_Date__c') && feedbackData.get('Stay_Date__c') != null) {
                feedback.Stay_Date__c = Date.valueOf((String)feedbackData.get('Stay_Date__c'));
            }
            
            // For picklist fields, we use the simplified values (1, 2, 3, 4, 5)
            if (feedbackData.containsKey('Overall_Rating__c') && feedbackData.get('Overall_Rating__c') != null) {
                feedback.Overall_Rating__c = (String)feedbackData.get('Overall_Rating__c');
            }
            
            if (feedbackData.containsKey('Room_Cleanliness_Rating__c') && feedbackData.get('Room_Cleanliness_Rating__c') != null) {
                feedback.Room_Cleanliness_Rating__c = (String)feedbackData.get('Room_Cleanliness_Rating__c');
            }
            
            if (feedbackData.containsKey('Staff_Service_Rating__c') && feedbackData.get('Staff_Service_Rating__c') != null) {
                feedback.Staff_Service_Rating__c = (String)feedbackData.get('Staff_Service_Rating__c');
            }
            
            if (feedbackData.containsKey('Value_For_Money_Rating__c') && feedbackData.get('Value_For_Money_Rating__c') != null) {
                feedback.Value_For_Money_Rating__c = (String)feedbackData.get('Value_For_Money_Rating__c');
            }
            
            if (feedbackData.containsKey('Would_Recommend__c')) {
                feedback.Would_Recommend__c = (Boolean)feedbackData.get('Would_Recommend__c');
            }
            
            if (feedbackData.containsKey('Comments__c') && feedbackData.get('Comments__c') != null) {
                feedback.Comments__c = (String)feedbackData.get('Comments__c');
            }
            
            System.debug('Inserting feedback: ' + feedback);
            // Insert the feedback record
            insert feedback;
            
            return feedback.Id;
        } catch (Exception e) {
            System.debug('Error saving feedback: ' + e.getMessage());
            throw new AuraHandledException('Error saving feedback: ' + e.getMessage());
        }
    }
}