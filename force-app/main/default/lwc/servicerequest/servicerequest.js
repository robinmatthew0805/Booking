import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Import Apex methods
import getServiceTypes from '@salesforce/apex/ServiceRequestController.getServiceTypes';
import getServiceCost from '@salesforce/apex/ServiceRequestController.getServiceCost';
import createServiceRequest from '@salesforce/apex/ServiceRequestController.createServiceRequest';
import getCurrentGuestInfo from '@salesforce/apex/ServiceRequestController.getCurrentGuestInfo';
import validateReservation from '@salesforce/apex/ServiceRequestController.validateReservation';
import getRoomDetails from '@salesforce/apex/ServiceRequestController.getRoomDetails';

// Import user ID
import USER_ID from '@salesforce/user/Id';

// Add constants for session storage keys (from HotelReservation component)
const SESSION_STORAGE_KEYS = {
    CONTACT_INFO: 'hotelReservation_contactInfo',
    RESERVATION_INFO: 'hotelReservation_reservationInfo',
    BOOKING_INFO: 'hotelReservation_bookingInfo' // Added for booking number and PIN
};

export default class ServiceRequest extends NavigationMixin(LightningElement) {
    // Public properties
    @api reservationId; // Optional: If coming from a reservation detail
    
    // Track component state
    @track isLoading = false;
    @track isGuestUser = false;
    @track showServiceCost = false;
    @track showConfirmation = false;
    @track isSubmitDisabled = false; // Changed to false since we'll validate on submit
    @track serviceId = '';
    @track guestName = '';
    @track roomNumber = '';
    @track roomPin = '';
    @track bookingNumber = '';
    @track serviceCost = 0;
    @track validatingReservation = false;
    @track reservationValidated = false;
    @track validatedRoomId = ''; // To store room ID after validation
    @track validatedGuestId = ''; // New field to store the guest/contact ID
    
    // Form data
    @track serviceData = {
        guestName: '',
        bookingNumber: '',
        roomPin: '',
        requestedDateTime: this.getDefaultDateTime(),
        serviceType: '',
        requestDetails: '',
        termsAccepted: false,
        displayRoomNumber: '',
        guestId: '' // New field for guest ID
    };
    
    // Add storage for hotel reservation data
    @track hotelReservationData = {
        contact: null,
        reservation: null,
        booking: null // Added for booking info
    };
    
    // Options for dropdowns
    @track serviceTypeOptions = [];
    
    // Computed properties
    get minDateTime() {
        // Set minimum date time to current time
        const now = new Date();
        return now.toISOString().slice(0, 16);
    }
    
    get formattedServiceCost() {
        // Format as PHP/Peso
        return new Intl.NumberFormat('en-PH', { 
            style: 'currency', 
            currency: 'PHP' 
        }).format(this.serviceCost);
    }
    
    // Lifecycle hooks
    connectedCallback() {
        this.loadInitialData();
    }
    
    // Load initial data
    loadInitialData() {
        this.isLoading = true;
        
        // First load hotel reservation data from session storage
        this.loadHotelReservationData();
        
        // Check if current user is a guest
        this.checkCurrentUser();
        
        // Load service types
        this.loadServiceTypes();
    }
    
    // Method to load hotel reservation data from session storage
    loadHotelReservationData() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                // Try to get contact info from session storage
                const storedContactInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.CONTACT_INFO);
                if (storedContactInfo) {
                    this.hotelReservationData.contact = JSON.parse(storedContactInfo);
                    console.log('Loaded contact info from session storage:', this.hotelReservationData.contact);
                    
                    // If no guest info is provided by getCurrentGuestInfo, use this data
                    if (!this.isGuestUser && this.hotelReservationData.contact) {
                        const contact = this.hotelReservationData.contact;
                        // Pre-populate guest name from contact
                        this.serviceData.guestName = `${contact.FirstName} ${contact.LastName}`;
                    }
                }
                
                // Try to get reservation info from session storage
                const storedReservationInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.RESERVATION_INFO);
                if (storedReservationInfo) {
                    this.hotelReservationData.reservation = JSON.parse(storedReservationInfo);
                    console.log('Loaded reservation info from session storage:', this.hotelReservationData.reservation);
                    
                    // If reservation has special requests, pre-fill request details
                    if (this.hotelReservationData.reservation && 
                        this.hotelReservationData.reservation.Special_Requests__c) {
                        this.serviceData.requestDetails = 
                            `Reservation special requests: ${this.hotelReservationData.reservation.Special_Requests__c}`;
                    }
                }
                
                // Try to get booking info from session storage
                const storedBookingInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.BOOKING_INFO);
                if (storedBookingInfo) {
                    this.hotelReservationData.booking = JSON.parse(storedBookingInfo);
                    console.log('Loaded booking info from session storage:', this.hotelReservationData.booking);
                    
                    // Pre-populate booking number and PIN if available
                    if (this.hotelReservationData.booking) {
                        if (this.hotelReservationData.booking.bookingNumber) {
                            this.serviceData.bookingNumber = this.hotelReservationData.booking.bookingNumber;
                        }
                        
                        if (this.hotelReservationData.booking.pin) {
                            this.serviceData.roomPin = this.hotelReservationData.booking.pin;
                        }
                    }
                }
            }
            
            // If contact info not found in session storage, try cookies
            if (!this.hotelReservationData.contact) {
                const contactFromCookie = this.getContactInfoFromCookie();
                if (contactFromCookie) {
                    this.hotelReservationData.contact = contactFromCookie;
                    console.log('Loaded contact info from cookie:', this.hotelReservationData.contact);
                    
                    // If no guest info is provided, use this cookie data
                    if (!this.isGuestUser && this.hotelReservationData.contact) {
                        const contact = this.hotelReservationData.contact;
                        // Pre-populate guest name from contact
                        this.serviceData.guestName = `${contact.FirstName} ${contact.LastName}`;
                    }
                }
            }
        } catch (error) {
            console.error('Error loading hotel reservation data:', error);
        }
    }
    
    // Method to save booking information to session storage
    saveBookingInfoToStorage() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                // Create booking info object
                const bookingInfo = {
                    bookingNumber: this.serviceData.bookingNumber,
                    pin: this.serviceData.roomPin
                };
                
                // Save to session storage
                sessionStorage.setItem(SESSION_STORAGE_KEYS.BOOKING_INFO, JSON.stringify(bookingInfo));
                console.log('Saved booking info to session storage:', bookingInfo);
            }
        } catch (error) {
            console.error('Error saving booking info to storage:', error);
        }
    }
    
    // Method to retrieve contact info from cookie (from HotelReservation component)
    getContactInfoFromCookie() {
        try {
            if (typeof document !== 'undefined' && document.cookie) {
                const cookies = document.cookie.split(';');
                
                for (let i = 0; i < cookies.length; i++) {
                    const cookie = cookies[i].trim();
                    
                    if (cookie.startsWith(`${SESSION_STORAGE_KEYS.CONTACT_INFO}=`)) {
                        const cookieValue = cookie.substring(SESSION_STORAGE_KEYS.CONTACT_INFO.length + 1);
                        return JSON.parse(decodeURIComponent(cookieValue));
                    }
                }
            }
            
            return null;
        } catch (error) {
            console.error('Error retrieving contact info from cookie:', error);
            return null;
        }
    }
    
    // Check if current user is a guest with a reservation
    checkCurrentUser() {
        getCurrentGuestInfo()
            .then(result => {
                if (result) {
                    this.isGuestUser = true;
                    this.guestName = result.guestName;
                    this.roomNumber = result.roomNumber;
                    this.roomPin = result.roomPin;
                    this.bookingNumber = result.bookingNumber;
                    
                    // Update the service data
                    this.serviceData.guestName = result.guestName;
                    this.serviceData.bookingNumber = result.bookingNumber;
                    this.serviceData.roomPin = result.roomPin;
                    this.serviceData.displayRoomNumber = result.displayRoomNumber;
                    this.validatedRoomId = result.roomId;
                    
                    // Set guest ID if available
                    if (result.guestId) {
                        this.validatedGuestId = result.guestId;
                        this.serviceData.guestId = result.guestId;
                    }
                    
                    this.reservationValidated = true;
                    
                    // Save booking info to storage
                    this.saveBookingInfoToStorage();
                } else {
                    this.isGuestUser = false;
                    
                    // If not a guest user but we have hotel reservation data, use it
                    this.useHotelReservationDataIfAvailable();
                }
                
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
                
                // If error fetching guest info but we have hotel reservation data, use it
                this.useHotelReservationDataIfAvailable();
            });
    }
    
    // Method to use hotel reservation data if available and not a guest user
    useHotelReservationDataIfAvailable() {
        if (!this.isGuestUser && this.hotelReservationData.contact) {
            const contact = this.hotelReservationData.contact;
            
            // Only overwrite if not already set
            if (!this.serviceData.guestName) {
                this.serviceData.guestName = `${contact.FirstName} ${contact.LastName}`;
            }
            
            // We can also use contact email and phone for later reference if needed
            console.log('Using hotel reservation contact data:', {
                name: this.serviceData.guestName,
                email: contact.Email,
                phone: contact.Phone
            });
        }
    }
    
    // Load service types
    loadServiceTypes() {
        getServiceTypes()
            .then(result => {
                this.serviceTypeOptions = result.map(type => ({
                    label: type.label,
                    value: type.value
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }
    
    // Get default date time (current time + 1 hour, rounded to nearest hour)
    getDefaultDateTime() {
        const now = new Date();
        now.setHours(now.getHours() + 1);
        now.setMinutes(0);
        now.setSeconds(0);
        now.setMilliseconds(0);
        return now.toISOString().slice(0, 16);
    }
    
    // Handle input changes
    handleInputChange(event) {
        const field = event.target.name;
        const value = field === 'termsAccepted' ? event.target.checked : event.target.value;
        
        // Update the service data
        this.serviceData = { ...this.serviceData, [field]: value };
        
        // If guest name, booking number, or room PIN changes, reset validation status
        if (field === 'guestName' || field === 'bookingNumber' || field === 'roomPin') {
            this.reservationValidated = false;
            this.validatedRoomId = '';
            this.validatedGuestId = '';
            this.serviceData.guestId = '';
        }
    }
    
    // Handle service type change
    handleServiceTypeChange(event) {
        const serviceType = event.target.value;
        this.serviceData.serviceType = serviceType;
        
        // If service type is selected, get the cost
        if (serviceType) {
            this.isLoading = true;
            
            getServiceCost({ serviceType: serviceType })
                .then(result => {
                    this.serviceCost = result;
                    this.showServiceCost = true;
                    this.isLoading = false;
                })
                .catch(error => {
                    this.handleError(error);
                    this.isLoading = false;
                });
        } else {
            this.showServiceCost = false;
        }
    }
    
    // Validate reservation information - will be called when Submit is clicked
    validateReservationInfo() {
        if (this.validatingReservation) {
            return Promise.reject(new Error('Validation already in progress'));
        }
        
        this.validatingReservation = true;
        this.isLoading = true;
        
        return validateReservation({
            guestName: this.serviceData.guestName,
            bookingNumber: this.serviceData.bookingNumber,
            roomPin: this.serviceData.roomPin,
            requestedDateTime: this.serviceData.requestedDateTime
        })
        .then(result => {
            if (result.isValid) {
                this.reservationValidated = true;
                this.validatedRoomId = result.roomId;
                
                // Store guest ID if it's provided in the result
                if (result.guestId) {
                    this.validatedGuestId = result.guestId;
                    this.serviceData.guestId = result.guestId;
                }
                
                // Get room details to display the room number
                if (result.room && result.room.Room_Number__c) {
                    this.serviceData.displayRoomNumber = result.room.Room_Number__c;
                } else {
                    this.getRoomNumberFromId(this.validatedRoomId);
                }
                
                // Save validated booking info to storage
                this.saveBookingInfoToStorage();
                
                this.validatingReservation = false;
                this.isLoading = false;
                
                // Return success
                return { success: true };
            } else {
                this.reservationValidated = false;
                this.validatedRoomId = '';
                this.validatedGuestId = '';
                this.serviceData.guestId = '';
                this.showToast('Error', result.errorMessage, 'error');
                
                this.validatingReservation = false;
                this.isLoading = false;
                
                // Return failure
                return { success: false, message: result.errorMessage };
            }
        })
        .catch(error => {
            this.reservationValidated = false;
            this.validatedRoomId = '';
            this.validatedGuestId = '';
            this.serviceData.guestId = '';
            this.validatingReservation = false;
            this.isLoading = false;
            this.handleError(error);
            
            // Rethrow error
            return { success: false, message: this.getErrorMessage(error) };
        });
    }
    
    // Get room number from room ID
    getRoomNumberFromId(roomId) {
        if (!roomId) return;
        
        getRoomDetails({ roomId: roomId })
            .then(result => {
                if (result) {
                    this.serviceData.displayRoomNumber = result.roomNumber;
                }
            })
            .catch(error => {
                this.handleError(error);
            });
    }
    
    // Validate form before submitting
    validateForm() {
        const requiredFields = [
            'guestName',
            'bookingNumber',
            'roomPin',
            'requestedDateTime',
            'serviceType'
        ];
        
        // Check if all required fields are filled
        const allFieldsFilled = requiredFields.every(field => 
            this.serviceData[field] !== null && 
            this.serviceData[field] !== undefined && 
            this.serviceData[field] !== ''
        );
        
        // Check if terms are accepted
        const termsAccepted = this.serviceData.termsAccepted;
        
        return allFieldsFilled && termsAccepted;
    }
    
    // Handle submit - now does validation first, then submits if valid
    handleSubmit() {
        // First validate the form fields
        if (!this.validateForm()) {
            this.showToast('Error', 'Please fill in all required fields and accept the terms.', 'error');
            return;
        }
        
        // If already a guest user, skip validation
        if (this.isGuestUser) {
            this.processServiceRequest();
            return;
        }
        
        // Show loading indicator
        this.isLoading = true;
        
        // Validate reservation first, then proceed with submission
        this.validateReservationInfo()
            .then(validationResult => {
                if (validationResult.success) {
                    // If validation succeeded, proceed with service request
                    this.processServiceRequest();
                }
                // If validation failed, error is already shown to user
            })
            .catch(error => {
                this.isLoading = false;
                this.handleError(error);
            });
    }
    
    // Process service request after validation
    processServiceRequest() {
        this.isLoading = true;
        
        // Add contact email from hotel reservation if available
        let contactEmail = '';
        if (this.hotelReservationData.contact && this.hotelReservationData.contact.Email) {
            contactEmail = this.hotelReservationData.contact.Email;
        }
        
        // Prepare data for submission
        const serviceRequest = {
            guestName: this.serviceData.guestName,
            roomNumber: this.validatedRoomId, // Use the validated room ID
            roomPin: this.serviceData.roomPin,
            bookingNumber: this.serviceData.bookingNumber,
            requestedDateTime: this.serviceData.requestedDateTime,
            serviceType: this.serviceData.serviceType,
            requestDetails: this.serviceData.requestDetails,
            serviceCost: this.serviceCost,
            createdById: USER_ID,
            guestId: this.validatedGuestId, // Include the guest/contact ID
            contactEmail: contactEmail // Add contact email if available
        };
        
        // Call Apex method to create service request
        createServiceRequest({ serviceData: JSON.stringify(serviceRequest) })
            .then(result => {
                this.serviceId = result;
                this.showConfirmation = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }
    
    // Handle cancel
    handleCancel() {
        // Reset form
        this.resetForm();
        
        // Show toast
        this.showToast('Cancelled', 'Service request has been cancelled', 'info');
    }
    
    // Close confirmation modal
    handleCloseConfirmation() {
        this.showConfirmation = false;
        this.resetForm();
    }
    
    // Reset form
    resetForm() {
        this.serviceData = {
            guestName: this.isGuestUser ? this.guestName : '',
            bookingNumber: this.isGuestUser ? this.bookingNumber : '',
            roomPin: this.isGuestUser ? this.roomPin : '',
            requestedDateTime: this.getDefaultDateTime(),
            serviceType: '',
            requestDetails: '',
            termsAccepted: false,
            displayRoomNumber: this.isGuestUser ? this.serviceData.displayRoomNumber : '',
            guestId: this.isGuestUser ? this.validatedGuestId : ''
        };
        
        // If we have hotel reservation data and not a guest user, pre-populate
        if (!this.isGuestUser) {
            // Populate from contact data if available
            if (this.hotelReservationData.contact) {
                const contact = this.hotelReservationData.contact;
                this.serviceData.guestName = `${contact.FirstName} ${contact.LastName}`;
            }
            
            // Populate from booking data if available
            if (this.hotelReservationData.booking) {
                if (this.hotelReservationData.booking.bookingNumber) {
                    this.serviceData.bookingNumber = this.hotelReservationData.booking.bookingNumber;
                }
                
                if (this.hotelReservationData.booking.pin) {
                    this.serviceData.roomPin = this.hotelReservationData.booking.pin;
                }
            }
        }
        
        this.showServiceCost = false;
        this.serviceCost = 0;
        this.reservationValidated = this.isGuestUser;
        this.validatedRoomId = this.isGuestUser ? this.validatedRoomId : '';
        this.validatedGuestId = this.isGuestUser ? this.validatedGuestId : '';
    }
    
    // Get error message from error object
    getErrorMessage(error) {
        let errorMessage = 'Unknown error';
        
        if (error.body && error.body.message) {
            errorMessage = error.body.message;
        } else if (typeof error === 'string') {
            errorMessage = error;
        } else if (error.message) {
            errorMessage = error.message;
        }
        
        return errorMessage;
    }
    
    // Show toast notification
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
        const errorMessage = this.getErrorMessage(error);
        console.error('Error:', errorMessage);
        this.showToast('Error', errorMessage, 'error');
    }
}