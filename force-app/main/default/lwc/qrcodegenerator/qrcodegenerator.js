import { LightningElement } from 'lwc';
import encryptData from '@salesforce/apex/HashingUtility.encryptData';

export default class Qrcodegenerator extends LightningElement {
    inputValue = '';
    encryptedValue = '';
    qrCodeUrl = '';

    handleInputChange(event) {
        this.inputValue = event.target.value;
        console.log('🔹 Input value updated:', this.inputValue);
    }

    generateEncryptedQR() {
        console.log('🟢 Button Clicked!'); // Ensure button is triggering

        if (this.inputValue.trim() === '') {
            console.warn('⚠️ No input provided for encryption.');
            this.encryptedValue = 'Please enter a valid input';
            this.qrCodeUrl = '';
            return;
        }

        console.log('🔹 Calling Apex encryptData() with input:', this.inputValue);

        encryptData({ input: this.inputValue })
            .then(result => {
                console.log('✅ Encryption successful:', result);
                this.encryptedValue = result;
                this.qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(result)}`;
                console.log('🔗 QR Code URL generated:', this.qrCodeUrl);
            })
            .catch(error => {
                console.error('❌ Encryption Error:', error);
                this.encryptedValue = 'Error encrypting data';
                this.qrCodeUrl = '';
            });
    }
}