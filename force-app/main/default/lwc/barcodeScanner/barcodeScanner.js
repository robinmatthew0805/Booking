import { LightningElement, api } from 'lwc';
import { FlowNavigationNextEvent, FlowAttributeChangeEvent } from 'lightning/flowSupport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getBarcodeScanner } from 'lightning/mobileCapabilities';
import decryptData from '@salesforce/apex/HashingUtility.decryptData';

export default class BarcodeScanner extends LightningElement {
    scanner;
    scanButtonDisabled = false;
    
    @api scannedBarcode = '';
    @api decryptedBarcode = '';
    @api parsedData = {};
    @api label;
    @api autoNavigate;
    @api buttonLabel = 'Scan';
    @api buttonIcon = 'utility:scan';
    @api scannerInstructions;
    @api availableActions = [];
    @api scanContinuously;
    @api allscannedBarcodes = [];

    // Fields from QR JSON
    @api bookingNumber = '';
    @api roomNumber = '';
    @api floorNumber = '';
    @api expiryDate = '';
    @api isExpired = false;

    connectedCallback() {
        this.scanner = getBarcodeScanner();
        this.scanButtonDisabled = !this.scanner || !this.scanner.isAvailable();
    }

    handleBeginScanClick() {
        this.resetFields();
        
        if (!this.scanner || !this.scanner.isAvailable()) {
            this.showToast('Barcode Scanner Is Not Available', 
                'Try again from a supported app on a mobile device.', 'error');
            return;
        }

        const scanningOptions = {
            barcodeTypes: [],
            instructionText: this.scanContinuously ? this.scannerInstructions : undefined,
            successText: this.scanContinuously ? 'Scanning Complete' : undefined
        };

        this.scanner.beginCapture(scanningOptions)
            .then(result => {
                console.log('🔹 Scan result:', result);
                this.processScannedBarcode(result);
                
                if (this.autoNavigate && this.availableActions.includes('NEXT')) {
                    this.dispatchEvent(new FlowNavigationNextEvent());
                }
            })
            .catch(error => {
                console.error('❌ Barcode Scanner Error:', error);
                this.showToast('Barcode Scanner Error',
                    'There was a problem scanning the barcode. Please try again.', 'error', 'sticky');
            })
            .finally(() => {
                this.scanner.endCapture();
            });
    }

    processScannedBarcode(barcode) {
        const scannedValue = decodeURIComponent(barcode.value);
        this.scannedBarcode = scannedValue;
        this.allscannedBarcodes.push(scannedValue);
        
        // Try parsing as JSON first
        try {
            const jsonData = JSON.parse(scannedValue);
            this.handleParsedJson(jsonData);
            this.decryptedBarcode = 'JSON Parsed Successfully';
            this.showToast('QR Code Parsed', 'QR code JSON data parsed successfully.', 'success');
        } catch (jsonError) {
            // If not JSON, try decryption
            this.attemptDecryption(scannedValue);
        }
    }

    handleParsedJson(jsonData) {
        this.extractFields(jsonData);
        this.parsedData = jsonData;
        this.dispatchAttributeChanges();
    }

    attemptDecryption(scannedValue) {
        decryptData({ encryptedData: scannedValue })
            .then(result => {
                this.decryptedBarcode = result;
                
                try {
                    // Try to parse decrypted result as JSON
                    const decryptedJson = JSON.parse(result);
                    this.handleParsedJson(decryptedJson);
                    this.showToast('Decryption Successful', 
                        'Decrypted and parsed JSON data successfully.', 'success');
                } catch (decryptJsonError) {
                    // Handle non-JSON decrypted data (comma-separated)
                    if (result.includes(',')) {
                        const parts = result.split(',');
                        if (parts.length >= 4) {
                            this.extractFields({
                                bookingNumber: parts[0] || '',
                                roomNumber: parts[1] || '',
                                floorNumber: parts[2] || '',
                                expiryDate: parts[3] || ''
                            });
                        }
                    }
                    this.dispatchAttributeChanges();
                }
            })
            .catch(error => {
                console.error('❌ Decryption Failed:', error);
                this.decryptedBarcode = 'Decryption Failed';
                this.showToast('Decryption Error', 'Could not decrypt the barcode.', 'error');
            });
    }

    extractFields(data) {
        this.bookingNumber = data.bookingNumber || '';
        this.roomNumber = data.roomNumber || '';
        this.floorNumber = data.floorNumber || '';
        this.expiryDate = data.expiryDate || '';
        this.checkExpiry(this.expiryDate);
    }

    checkExpiry(expiryDateStr) {
        if (!expiryDateStr) {
            this.isExpired = true; // Empty date = expired
            return;
        }
        
        try {
            const expiryDate = new Date(expiryDateStr);
            this.isExpired = isNaN(expiryDate.getTime()) || expiryDate < new Date();
        } catch (error) {
            this.isExpired = true; // Error = expired
        }
    }

    dispatchAttributeChanges() {
        const fields = [
            'scannedBarcode', 'decryptedBarcode', 'bookingNumber', 
            'roomNumber', 'floorNumber', 'expiryDate', 'isExpired', 'parsedData'
        ];
        
        fields.forEach(field => {
            this.dispatchEvent(new FlowAttributeChangeEvent(field, this[field]));
        });
    }

    resetFields() {
        const fields = [
            'scannedBarcode', 'decryptedBarcode', 'bookingNumber', 
            'roomNumber', 'floorNumber', 'expiryDate', 'parsedData'
        ];
        
        fields.forEach(field => {
            this[field] = field === 'parsedData' ? {} : '';
        });
        
        this.isExpired = false;
    }

    showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode
            })
        );
    }
}