@isTest
public class HashingUtilityTest {
    
    // Setup test data
    @TestSetup
    static void setupTestData() {
        // Create custom label mocks using Test.setMock if necessary
        // This would be implementation-specific based on how you handle custom labels in tests
    }
    
    @isTest
    static void testEncryptionWithValidInput() {
        // Arrange
        String testData = 'Test sensitive data 123!@#';
        
        // Act
        Test.startTest();
        String encryptedResult = HashingUtility.encryptData(testData);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals('Invalid Input', encryptedResult, 'Should not return error message for valid input');
        System.assertNotEquals(testData, encryptedResult, 'Encrypted data should differ from original data');
        System.assert(encryptedResult.length() > 0, 'Encrypted result should not be empty');
    }
    
    @isTest
    static void testEncryptionWithEmptyInput() {
        // Arrange
        String testData = '';
        
        // Act
        Test.startTest();
        String encryptedResult = HashingUtility.encryptData(testData);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Invalid Input', encryptedResult, 'Should return error message for empty input');
    }
    
    @isTest
    static void testEncryptionWithNullInput() {
        // Arrange
        String testData = null;
        
        // Act
        Test.startTest();
        String encryptedResult = HashingUtility.encryptData(testData);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Invalid Input', encryptedResult, 'Should return error message for null input');
    }
    
    @isTest
    static void testDecryptionWithValidInput() {
        // Arrange
        String originalData = 'Test sensitive data 123!@#';
        
        // Act
        Test.startTest();
        String encryptedResult = HashingUtility.encryptData(originalData);
        String decryptedResult = HashingUtility.decryptData(encryptedResult);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals('Invalid Input', decryptedResult, 'Should not return error message for valid input');
        System.assertEquals(originalData, decryptedResult, 'Decrypted data should match original data');
    }
    
    @isTest
    static void testDecryptionWithEmptyInput() {
        // Arrange
        String testData = '';
        
        // Act
        Test.startTest();
        String decryptedResult = HashingUtility.decryptData(testData);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Invalid Input', decryptedResult, 'Should return error message for empty input');
    }
    
    @isTest
    static void testDecryptionWithNullInput() {
        // Arrange
        String testData = null;
        
        // Act
        Test.startTest();
        String decryptedResult = HashingUtility.decryptData(testData);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Invalid Input', decryptedResult, 'Should return error message for null input');
    }
    
    @isTest
    static void testDecryptionWithInvalidInput() {
        // Arrange
        String invalidEncryptedData = 'ThisIsNotValidEncryptedData';
        
        // Act
        Test.startTest();
        String decryptedResult = HashingUtility.decryptData(invalidEncryptedData);
        Test.stopTest();
        
        // Assert
        System.assert(decryptedResult.startsWith('Decryption Failed:'), 
                     'Should return decryption failure message for invalid encrypted data');
    }
    
    @isTest
    static void testEndToEndEncryptionDecryption() {
        // Arrange - Test various data types and special characters
        List<String> testDataSet = new List<String>{
            'Regular text',
            'Special ch@r&cters!',
            '123456789',
            'Multi\nLine\rText',
            'JSON {"key": "value"}',
            'Very long text ' + 'a'.repeat(1000)
        };
        
        for(String testData : testDataSet) {
            // Act
            Test.startTest();
            String encrypted = HashingUtility.encryptData(testData);
            String decrypted = HashingUtility.decryptData(encrypted);
            Test.stopTest();
            
            // Assert
            System.assertEquals(testData, decrypted, 
                               'End-to-end encryption and decryption should preserve original data: ' + testData);
        }
    }
    
    // Helper method for creating a string of repeated characters (since Apex doesn't have String.repeat)
    private static String repeat(String s, Integer times) {
        String result = '';
        for(Integer i = 0; i < times; i++) {
            result += s;
        }
        return result;
    }
}