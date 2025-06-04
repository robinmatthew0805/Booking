public with sharing class HashingUtility {
    private static final String AES_ALGORITHM = 'AES256'; // ✅ Ensure AES-256 encryption

    private static Blob getDecodedSecretKey() {
        System.debug('🔹 Decoding Secret Key from Base64...');
        return EncodingUtil.base64Decode(Label.EncryptionKey); // ✅ Decoding Base64 Key
    }

    private static Blob getDecodedIV() {
        System.debug('🔹 Decoding IV from Base64...');
        return EncodingUtil.base64Decode(Label.EncryptionIV); // ✅ Decoding Base64 IV
    }

    @AuraEnabled(cacheable=false)
    public static String encryptData(String input) {
        System.debug('🟢 Received input for encryption: ' + input);

        if (String.isEmpty(input)) {
            System.debug('⚠️ Input is empty or null.');
            return 'Invalid Input';
        }

        try {
            Blob keyBlob = getDecodedSecretKey(); 
            Blob ivBlob = getDecodedIV();
            Blob inputBlob = Blob.valueOf(input);

            System.debug('Prepared Key & IV. Encrypting now...');

            Blob encryptedBlob = Crypto.encrypt(AES_ALGORITHM, keyBlob, ivBlob, inputBlob);
            String encodedResult = EncodingUtil.base64Encode(encryptedBlob);

            System.debug('✅ Encryption successful: ' + encodedResult);
            return encodedResult;
        } catch (Exception e) {
            System.debug('Encryption Failed: ' + e.getMessage());
            return 'Encryption Failed: ' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String decryptData(String encryptedData) {
        System.debug('🔹 Received input for decryption: ' + encryptedData);

        if (String.isEmpty(encryptedData)) {
            System.debug('⚠️ Encrypted input is empty or null.');
            return 'Invalid Input';
        }

        try {
            Blob keyBlob = getDecodedSecretKey(); //Decoded AES-256 Key
            Blob ivBlob = getDecodedIV(); //Decoded 16-byte IV
            Blob encryptedBlob = EncodingUtil.base64Decode(encryptedData);

            System.debug('Prepared Key & IV. Decrypting now...');

            Blob decryptedBlob = Crypto.decrypt(AES_ALGORITHM, keyBlob, ivBlob, encryptedBlob);
            String decodedResult = decryptedBlob.toString();

            System.debug('Decryption successful: ' + decodedResult);
            return decodedResult;
        } catch (Exception e) {
            System.debug('Decryption Failed: ' + e.getMessage());
            return 'Decryption Failed: ' + e.getMessage();
        }
    }
}