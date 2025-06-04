import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import encryptData from '@salesforce/apex/HashingUtility.encryptData';
import SECRET_KEY from '@salesforce/label/c.EncryptionKey';
import IV from '@salesforce/label/c.EncryptionIV';
import getReservationByDetails from '@salesforce/apex/ReservationController.getReservationByDetails';
import createRoomKey from '@salesforce/apex/ReservationController.createRoomKey';
import checkOutReservation from '@salesforce/apex/ReservationController.checkOutReservation';
import getExistingQRCode from '@salesforce/apex/ReservationController.getExistingQRCode';
import saveFeedback from '@salesforce/apex/FeedbackController.saveFeedback';

// Define session storage keys
const SESSION_STORAGE_KEYS = {
    CONTACT_INFO: 'hotelReservation_contactInfo',
    RESERVATION_INFO: 'hotelReservation_reservationInfo',
    BOOKING_INFO: 'hotelReservation_bookingInfo'
};

export default class CheckInCheckOut extends LightningElement {
    @track bookingNumber = '';
    @track guestName = '';
    @track pinNumber = '';
    @track expiryDate = this.getDefaultExpiryDate();
    @track isLoading = false;
    @track isFormLoading = false;
    @track noDataFound = false;
    @track hasReservationData = false;
    @track isCheckedIn = false;
    @track isNotCheckedIn = true; 
    @track qrCodeUrl = '';
    @track hashedKey = '';
    @track floorNumber = '';
    @track guestNameFromResult = '';
    
    // Checkout confirmation modal
    @track showCheckoutConfirmation = false;
    
    // Feedback form properties
    @track showFeedbackForm = false;
    @track feedbackData = {
        Overall_Rating__c: null,
        Room_Cleanliness_Rating__c: null,
        Staff_Service_Rating__c: null,
        Value_For_Money_Rating__c: null,
        Would_Recommend__c: false,
        Comments__c: '',
        Guests__c: null,
        Reservation__c: null,
        Stay_Date__c: null
    };
    
    // Rating options for the fields - using exact values that match Salesforce (1, 2, 3, 4, 5)
    // but showing descriptive labels to the user
    get ratingOptions() {
        return [
            { label: '5 - Excellent', value: '5' },
            { label: '4 - Very Good', value: '4' },
            { label: '3 - Good', value: '3' },
            { label: '2 - Fair', value: '2' },
            { label: '1 - Poor', value: '1' }
        ];
    }
    
    // Reservation data object
    @track reservation = {
        id: '',
        guestName: '',
        checkInDate: '',
        checkOutDate: '',
        roomNumber: '',
        roomType: '',
        paymentStatus: '',
        status: '',
        specialRequests: '',
        pin: ''
    };
    
    // Lifecycle hook
    connectedCallback() {
        // Load booking info from session storage
        this.loadBookingDataFromStorage();
    }
    
    // Calculate default expiry date (tomorrow at checkout time)
    getDefaultExpiryDate() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(11, 0, 0); // Default checkout time 11:00 AM
        return this.formatDateForInput(tomorrow);
    }
    
    // Format date for datetime-local input
    formatDateForInput(date) {
        return date.toISOString().slice(0, 16);
    }
    
    // Load booking data from session storage
    loadBookingDataFromStorage() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                // Try to get booking info from session storage
                const storedBookingInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.BOOKING_INFO);
                if (storedBookingInfo) {
                    const bookingData = JSON.parse(storedBookingInfo);
                    
                    // Populate booking fields from storage
                    if (bookingData.bookingNumber) {
                        this.bookingNumber = bookingData.bookingNumber;
                    }
                    
                    if (bookingData.pin) {
                        this.pinNumber = bookingData.pin;
                    }
                    
                    console.log('Loaded booking info from session storage');
                }
                
                // Try to get contact info from session storage for guest name
                const storedContactInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.CONTACT_INFO);
                if (storedContactInfo) {
                    const contactData = JSON.parse(storedContactInfo);
                    
                    // Populate guest name if available
                    if (contactData.FirstName && contactData.LastName) {
                        this.guestName = `${contactData.FirstName} ${contactData.LastName}`;
                    }
                    
                    console.log('Loaded contact info from session storage');
                }
            }
        } catch (error) {
            console.error('Error loading booking data from storage:', error);
        }
    }
    
    // Save booking information to session storage
    saveBookingInfoToStorage() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                // Create booking info object
                const bookingInfo = {
                    bookingNumber: this.bookingNumber,
                    pin: this.pinNumber
                };
                
                // Save to session storage
                sessionStorage.setItem(SESSION_STORAGE_KEYS.BOOKING_INFO, JSON.stringify(bookingInfo));
                console.log('Saved booking info to session storage');
            }
        } catch (error) {
            console.error('Error saving booking info to storage:', error);
        }
    }
    
    // Handle booking number input change
    handleBookingNumberChange(event) {
        this.bookingNumber = event.target.value;
        this.resetData();
    }
    
    // Handle guest name input change
    handleGuestNameChange(event) {
        this.guestName = event.target.value;
        this.resetData();
    }
    
    // Handle PIN input change
    handlePinNumberChange(event) {
        this.pinNumber = event.target.value;
        this.resetData();
    }
    
    // Handle expiry date change
    handleExpiryDateChange(event) {
        this.expiryDate = event.target.value;
    }
    
    // Reset component data
    resetData() {
        this.hasReservationData = false;
        this.noDataFound = false;
        this.isCheckedIn = false;
        this.isNotCheckedIn = true;
        this.qrCodeUrl = '';
        this.hashedKey = '';
        this.showFeedbackForm = false;
        this.showCheckoutConfirmation = false;
    }
    
    // Search for reservation
    searchReservation() {
        if (!this.bookingNumber) {
            this.showToast('Error', 'Please enter a Booking Number', 'error');
            return;
        }
        
        if (!this.guestName) {
            this.showToast('Error', 'Please enter Guest Name', 'error');
            return;
        }
        
        if (!this.pinNumber) {
            this.showToast('Error', 'Please enter the 6-digit PIN from your confirmation email', 'error');
            return;
        }
        
        this.isLoading = true;
        
        // Call Apex method to get reservation by booking number, name and PIN
        getReservationByDetails({ 
            bookingNumber: this.bookingNumber,
            guestName: this.guestName,
            pin: this.pinNumber
        })
        .then(result => {
            console.log('Reservation result:', result);
            
            if (result && result.Id) { // Ensure valid data
                // Extract floor number from room information if available
                if (result.Room__r && result.Room__r.Floor__c) {
                    this.floorNumber = result.Room__r.Floor__c;
                }

                this.guestNameFromResult = result.Guest_Name__c;
                
                this.reservation = {
                    id: result.Id,
                    guestName: result.Guest_Name__r ? result.Guest_Name__r.Name : 'N/A',
                    checkInDate: this.formatDate(result.Check_In__c),
                    checkOutDate: this.formatDate(result.Check_Out__c),
                    roomNumber: result.Room__r ? result.Room__r.Room_Number__c : 'N/A',
                    roomType: result.Room_Type__c || 'N/A',
                    paymentStatus: result.Payment_Status__c || 'N/A',
                    status: result.Status__c || 'New',
                    specialRequests: result.Special_Requests__c || 'None',
                    pin: result.PIN__c || 'N/A',
                    rawCheckInDate: result.Check_In__c  // Store raw check-in date for validation
                };
    
                this.hasReservationData = true;
                this.noDataFound = false;
                
                // Save successful booking info to storage for reuse
                this.saveBookingInfoToStorage();
                
                // Check if reservation is already checked in
                if (result.Status__c === 'Checked-in') {
                    this.isCheckedIn = true;
                    this.isNotCheckedIn = false;
                    
                    // Check for existing QR code
                    this.checkForExistingQRCode();
                } else {
                    // Check if check-in date is today or in the past
                    const checkInDate = new Date(result.Check_In__c);
                    const today = new Date();
                    
                    // Reset hours to compare just the dates
                    checkInDate.setHours(0, 0, 0, 0);
                    today.setHours(0, 0, 0, 0);
                    
                    if (checkInDate.getTime() <= today.getTime()) {
                        // Allow check-in if today or past due
                        this.isCheckedIn = false;
                        this.isNotCheckedIn = true;
                    } else {
                        // Future check-in date - prevent check-in
                        this.isCheckedIn = false;
                        this.isNotCheckedIn = true;
                        this.showToast('Info', 'This reservation\'s check-in date is in the future. Check-in is only available on or after the scheduled date.', 'info');
                    }
                }
                
                this.isLoading = false;
            } else {
                console.warn('No reservation data found or reservation is checked out');
                this.hasReservationData = false;
                this.noDataFound = true;
                this.showToast('Info', 'No active reservation found with the provided details.', 'info');
                this.isLoading = false;
            }
        })
        .catch(error => {
            console.error('Error fetching reservation:', error);
            this.isLoading = false;
            this.handleError(error);
        });
    }
    
    // Check for existing QR code in the database
    checkForExistingQRCode() {
        getExistingQRCode({ reservationId: this.reservation.id })
            .then(result => {
                if (result) {
                    // Use existing hash to generate QR code
                    this.hashedKey = result;
                    this.qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(result)}`;
                } else {
                    // No existing code, generate a new one
                    this.generateNewQRCodeForExistingReservation();
                }
            })
            .catch(error => {
                console.error('Error checking for existing QR code:', error);
                // Fallback to generating a new code
                this.generateNewQRCodeForExistingReservation();
            });
    }
    
    // Format date for display
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit' 
        }).format(date);
    }
    
    // Handle Check-In
    handleCheckIn() {
        if (!this.validateCheckIn()) {
            return;
        }
        
        // Check if check-in date is today or in the past
        const checkInDate = new Date(this.reservation.rawCheckInDate);
        const today = new Date();
        
        // Reset hours to compare just the dates
        checkInDate.setHours(0, 0, 0, 0);
        today.setHours(0, 0, 0, 0);
        
        if (checkInDate.getTime() > today.getTime()) {
            this.showToast('Error', 'Cannot check in before the scheduled check-in date. Your check-in date is ' + 
                this.formatDate(this.reservation.rawCheckInDate), 'error');
            return;
        }
        
        this.isLoading = true;
        
        // Prepare the QR code data
        const qrData = {
            bookingNumber: this.reservation.id,
            roomNumber: this.reservation.roomNumber.toString(),
            floorNumber: this.floorNumber.toString(),
            expiryDate: this.expiryDate.toString()
        };
        
        // Generate encrypted QR code
        encryptData({ input: JSON.stringify(qrData), key: SECRET_KEY, iv: IV })
            .then(result => {
                // Store hashed result
                this.hashedKey = result;
                // Generate QR code URL
                this.qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(result)}`;
                
                // Create Room and Floor Key record
                const keyData = {
                    reservationID: this.reservation.id,
                    roomNumber: this.reservation.roomNumber,
                    expiryDate: this.expiryDate,
                    floorNumber: this.floorNumber,
                    guestName: this.guestNameFromResult,
                    hashResult: this.hashedKey
                };

                console.log('Keydata', JSON.stringify(keyData));
                
                return createRoomKey({ keyData: JSON.stringify(keyData) });
            })
            .then(result => {
                this.isLoading = false;
                
                if (result) {
                    this.isCheckedIn = true;
                    this.isNotCheckedIn = false;
                    this.reservation.status = 'Checked-in';
                    this.showToast('Success', 'Guest has been checked in and room key generated', 'success');
                } else {
                    this.showToast('Error', 'Failed to create room key', 'error');
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.handleError(error);
            });
    }
    
    // Handle Check-Out button click - Show the confirmation dialog
    handleCheckOut() {
        if (!this.isCheckedIn) {
            this.showToast('Error', 'Reservation is not checked in', 'error');
            return;
        }
        
        // Show confirmation dialog first
        this.showCheckoutConfirmation = true;
    }
    
    // Handle cancel checkout confirmation
    handleCancelCheckout() {
        this.showCheckoutConfirmation = false;
    }
    
    // Handle confirm checkout - Show the feedback form
    handleConfirmCheckout() {
        this.showCheckoutConfirmation = false;
        
        // Show the feedback form modal
        this.showFeedbackForm = true;
    }
    
    // Handle feedback field changes
    handleFeedbackFieldChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.feedbackData[field] = value;
    }
    
    // Skip feedback and proceed to checkout
    handleSkipFeedback() {
        this.showFeedbackForm = false;
        this.processCheckout();
    }
    
    // Submit feedback and proceed to checkout
    handleSubmitFeedback() {
        // Basic validation
        if (!this.feedbackData.Overall_Rating__c) {
            this.showToast('Error', 'Please provide an overall rating', 'error');
            return;
        }
        
        this.isFormLoading = true;
        
        // Set the stay date based on the checkout date
        // If checkout date is today or in the future, use today's date
        // If checkout date is in the past, use the checkout date
        let stayDate = new Date().toISOString().slice(0, 10); // Default to today
        
        if (this.reservation.checkOutDate) {
            const checkoutDate = new Date(this.reservation.checkOutDate);
            const today = new Date();
            
            // Reset hours to compare just the dates
            checkoutDate.setHours(0, 0, 0, 0);
            today.setHours(0, 0, 0, 0);
            
            if (checkoutDate < today) {
                // If checkout date is in the past, use it as the stay date
                stayDate = checkoutDate.toISOString().slice(0, 10);
            }
        }
        
        // The feedbackData object is already in the correct format for Salesforce
        // Just need to make sure all required fields are set
        this.feedbackData.Reservation__c = this.reservation.id;
        this.feedbackData.Guests__c = this.guestNameFromResult;
        this.feedbackData.Stay_Date__c = stayDate;
        
        // Create a copy of the feedback data for saving
        const feedbackToSave = { ...this.feedbackData };
        
        // Call Apex method to save feedback
        saveFeedback({ feedbackData: feedbackToSave })
            .then(result => {
                if (result) {
                    this.showToast('Success', 'Thank you for your feedback!', 'success');
                    this.showFeedbackForm = false;
                    this.processCheckout();
                } else {
                    this.showToast('Error', 'Failed to save feedback', 'error');
                    this.isFormLoading = false;
                }
            })
            .catch(error => {
                console.error('Error saving feedback:', error);
                this.showToast('Error', 'An error occurred while saving your feedback', 'error');
                this.isFormLoading = false;
            });
    }
    
    // Process the actual checkout
    processCheckout() {
        this.isLoading = true;
        
        checkOutReservation({ bookingNumber: this.reservation.id })
            .then(result => {
                this.isLoading = false;
                
                if (result) {
                    this.showToast('Success', 'Guest has been checked out successfully', 'success');
                    this.resetFields();
                    
                    // Also clear session storage when checking out
                    this.clearStoredBookingData();
                } else {
                    this.showToast('Error', 'Failed to check out guest', 'error');
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.handleError(error);
            });
    }
    
    // Generate QR code for existing checked-in reservation
    generateNewQRCodeForExistingReservation() {
        // For already checked-in reservations, we'll generate a new QR code
        // with the current information for display purposes
        const qrData = {
            bookingNumber: this.reservation.id,
            roomNumber: this.reservation.roomNumber,
            floorNumber: this.floorNumber,
            expiryDate: this.expiryDate
        };
        
        encryptData({ input: JSON.stringify(qrData), key: SECRET_KEY, iv: IV })
            .then(result => {
                // Generate QR code URL
                this.hashedKey = result;
                this.qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(result)}`;
            })
            .catch(error => {
                console.error('Encryption Error:', error);
                this.showToast('Error', 'Failed to encrypt data for QR code', 'error');
            });
    }
    
    // Validate Check-In data
    validateCheckIn() {
        // Validate expiry date
        if (!this.expiryDate) {
            this.showToast('Error', 'Please set an expiry date and time', 'error');
            return false;
        }
        
        const expiryDateTime = new Date(this.expiryDate);
        const now = new Date();
        
        if (expiryDateTime <= now) {
            this.showToast('Error', 'Expiry date must be in the future', 'error');
            return false;
        }
        
        return true;
    }
    
    // Clear stored booking data (called after checkout)
    clearStoredBookingData() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                sessionStorage.removeItem(SESSION_STORAGE_KEYS.BOOKING_INFO);
                console.log('Cleared stored booking data');
            }
        } catch (error) {
            console.error('Error clearing stored booking data:', error);
        }
    }
    
    // Reset all fields after checkout
    resetFields() {
        this.bookingNumber = '';
        this.guestName = '';
        this.pinNumber = '';
        this.expiryDate = this.getDefaultExpiryDate();
        this.hasReservationData = false;
        this.noDataFound = false;
        this.isCheckedIn = false;
        this.isNotCheckedIn = true;
        this.qrCodeUrl = '';
        this.hashedKey = '';
        this.floorNumber = '';
        this.guestNameFromResult = '';
        this.showFeedbackForm = false;
        this.showCheckoutConfirmation = false;
        
        // Reset feedback data
        this.feedbackData = {
            Overall_Rating__c: null,
            Room_Cleanliness_Rating__c: null,
            Staff_Service_Rating__c: null,
            Value_For_Money_Rating__c: null,
            Would_Recommend__c: false,
            Comments__c: '',
            Guests__c: null,
            Reservation__c: null,
            Stay_Date__c: null
        };
        
        // Reset reservation data
        this.reservation = {
            id: '',
            guestName: '',
            checkInDate: '',
            checkOutDate: '',
            roomNumber: '',
            roomType: '',
            paymentStatus: '',
            status: '',
            specialRequests: '',
            pin: ''
        };
    }
    
    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    // Handle errors
    handleError(error) {
        let errorMessage = 'Unknown error';
        
        if (error.body && error.body.message) {
            errorMessage = error.body.message;
        } else if (typeof error === 'string') {
            errorMessage = error;
        }
        
        console.error('Error:', errorMessage);
        this.showToast('Error', errorMessage, 'error');
    }

    get statusClass() {
        const status = this.reservation?.status?.toLowerCase() || '';
        
        if (status === 'checked-in') {
            return 'status-checked-in';
        } else if (status === 'new') {
            return 'status-new';
        }
        
        return '';
    }
}