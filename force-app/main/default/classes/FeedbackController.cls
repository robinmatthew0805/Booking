public with sharing class FeedbackController {
    @AuraEnabled
    public static Id saveFeedback(Map<String, Object> feedbackData) {
        try {
            return FeedbackService.saveFeedback(feedbackData);
        } catch (Exception e) {
            System.debug('Error saving feedback in controller: ' + e.getMessage());
            throw new AuraHandledException('Error saving feedback: ' + e.getMessage());
        }
    }
}