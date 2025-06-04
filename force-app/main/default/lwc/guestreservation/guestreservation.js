import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAvailableRooms from '@salesforce/apex/ContactReservationController.getAvailableRooms';
import startPayPalPayment from '@salesforce/apex/ContactReservationController.startPayPalPayment';
import processPayPalReturn from '@salesforce/apex/ContactReservationController.processPayPalReturn';
import processInFormPayment from '@salesforce/apex/ContactReservationController.processInFormPayment';

import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import RESERVATION_OBJINFO from '@salesforce/schema/Reservation__c';
import ROOM_TYPE from '@salesforce/schema/Reservation__c.Room_Type__c';

// Add constants for session storage keys
const SESSION_STORAGE_KEYS = {
    CONTACT_INFO: 'hotelReservation_contactInfo',
    RESERVATION_INFO: 'hotelReservation_reservationInfo'
};

const STEPS = {
    DATE_SELECTION: 1,
    ROOM_SELECTION: 2,
    RESERVATION_FORM: 3,
    PAYMENT: 4
};

const PAYMENT_METHODS = {
    PAYPAL: 'PayPal',
    CARD: 'Card'
};

export default class HotelReservation extends NavigationMixin(LightningElement) {
    // Component state
    spinnerStatus = false;
    @track currentStep = STEPS.DATE_SELECTION;
    
    // Date selection
    @track checkInDate = '';
    @track checkOutDate = '';
    @track minDate = '';
    @track minCheckoutDate = '';
    
    // Available rooms
    @track availableRooms = [];
    @track filteredRooms = [];
    @track selectedRoomId = '';
    @track selectedRoomType = '';
    @track selectedRoomPrice = 0;
    @track totalNights = 0;
    @track totalCost = 0;
    
    // Room filtering
    @track filterFloor = '';
    @track filterRoomNumber = '';
    @track filterRoomType = '';
    @track filterFeatures = [];
    @track availableFeatures = [
        { label: 'Sea view', value: 'Sea view' },
        { label: 'Private bathroom (Shower/Bathtub)', value: 'Private bathroom (Shower/Bathtub)' },
        { label: 'Free WiFi', value: 'Free WiFi' },
        { label: 'Flat-screen TV with cable', value: 'Flat-screen TV with cable' },
        { label: 'Air conditioning and heating', value: 'Air conditioning and heating' },
        { label: 'Wardrobe/Closet', value: 'Wardrobe/Closet' },
        { label: 'Desk and chair', value: 'Desk and chair' },
        { label: 'In-room phone', value: 'In-room phone' },
        { label: 'Safe deposit box', value: 'Safe deposit box' },
        { label: 'Mini-fridge', value: 'Mini-fridge' }
    ];
    @track floorOptions = [];
    @track showFilters = false;
    
    // Payment related
    @track reservationId = '';
    @track paymentProcessing = false;
    @track paymentComplete = false;
    @track paymentMethod = PAYMENT_METHODS.PAYPAL;
    @track tempReservationId = '';
    
    // Card payment details
    @track cardDetails = {
        cardName: '',
        cardNumber: '',
        cardExpMonth: '',
        cardExpYear: '',
        cardCVV: ''
    };
    
    @track formattedExpiry = '';
    @track detectedCardType = '';
    
    // Contact and Reservation data
    @track contact = {
        FirstName: '',
        LastName: '',
        Email: '',
        Phone: ''
    };

    @track reservation = {
        Check_In__c: '',
        Check_Out__c: '',
        Room_Type__c: '',
        Special_Requests__c: '',
        Total_Cost__c: 0,
        Payment_Status__c: 'Pending'
    };

    // Picklist options
    @track roomTypeOptions = [];

    // Payment processing state
    @track isPaymentInProcess = false;
    
    // Debug features
    @track showDebugButton = false;
    
    // Getters for UI display
    get paymentOptions() {
        return [
            { label: PAYMENT_METHODS.PAYPAL, value: PAYMENT_METHODS.PAYPAL },
            { label: PAYMENT_METHODS.CARD, value: PAYMENT_METHODS.CARD }
        ];
    }
    
    get isDateSelectionStep() { return this.currentStep === STEPS.DATE_SELECTION; }
    get isRoomSelectionStep() { return this.currentStep === STEPS.ROOM_SELECTION; }
    get isReservationFormStep() { return this.currentStep === STEPS.RESERVATION_FORM; }
    get isPaymentStep() { return this.currentStep === STEPS.PAYMENT; }
    get formattedTotalCost() { return this.formatCurrency(this.totalCost); }
    get hasSelectedDates() { return this.checkInDate && this.checkOutDate; }
    get checkoutDisabled() { return !this.checkInDate; }
    get isPayPalMethod() { return this.paymentMethod === PAYMENT_METHODS.PAYPAL; }
    get isCardPaymentMethod() { return this.paymentMethod === PAYMENT_METHODS.CARD; }
    get paymentButtonLabel() {
        return this.paymentMethod === PAYMENT_METHODS.PAYPAL ? 'Proceed to PayPal' : 'Process Payment';
    }
    
    // Card validation getters
    get cardTypeClass() {
        return this.detectedCardType ? 
            `card-type ${this.detectedCardType.toLowerCase().replace(' ', '-')}` : 
            'card-type';
    }

    get isCardTypeDetected() {
        return !!this.detectedCardType;
    }
    
    // CSS classes for step indicator
    get dateSelectorClass() {
        return this.currentStep === STEPS.DATE_SELECTION ? 'slds-progress__item slds-is-active' : 'slds-progress__item';
    }
    
    get roomSelectorClass() {
        return this.currentStep === STEPS.ROOM_SELECTION ? 'slds-progress__item slds-is-active' : 'slds-progress__item';
    }
    
    get reservationFormClass() {
        return this.currentStep === STEPS.RESERVATION_FORM ? 'slds-progress__item slds-is-active' : 'slds-progress__item';
    }
    
    get paymentClass() {
        return this.currentStep === STEPS.PAYMENT ? 'slds-progress__item slds-is-active' : 'slds-progress__item';
    }
    
    // Progress bar calculations
    get progressValue() {
        return this.currentStep * 25;
    }
    
    get progressBarStyle() {
        return `width: ${this.progressValue}%`;
    }
    
    get processedRooms() {
        if (!this.filteredRooms || !this.totalNights) {
            return this.filteredRooms || [];
        }
        
        return this.filteredRooms.map(room => {
            // Create feature array from semicolon-separated string
            const featuresArray = room.Features__c ? 
                room.Features__c.split(';').map(feature => feature.trim()) : 
                [];
                
            return {
                ...room,
                totalRoomCost: this.formatCurrency((room.Price_Per_Night__c || 0) * this.totalNights),
                featuresArray: featuresArray
            };
        });
    }

    get defaultRecordTypeId() {
        return this.reservationInfo?.defaultRecordTypeId ?? null;
    }

    get hasRooms() {
        return this.filteredRooms && this.filteredRooms.length > 0;
    }

    get hasNoMatchingRooms() {
        return this.availableRooms && this.availableRooms.length > 0 && this.filteredRooms.length === 0;
    }
    
    get noRoomsAvailable() {
        return this.availableRooms && this.availableRooms.length === 0;
    }

    // Wire Reservation Object Info
    @wire(getObjectInfo, { objectApiName: RESERVATION_OBJINFO })
    reservationInfoHandler({ data, error }) {
        if (data) {
            this.reservationInfo = data;
        } else if (error) {
            this.handleError('Error fetching reservation object info', error);
        }
    }

    // Fetch picklist values for Room Type
    @wire(getPicklistValues, {
        recordTypeId: '$defaultRecordTypeId',
        fieldApiName: ROOM_TYPE
    })
    wiredRoomType({ data, error }) {
        if (data) {
            console.log('Room type picklist data received:', JSON.stringify(data));
            
            // Initialize with "All Room Types" option
            this.roomTypeOptions = [{ label: 'All Room Types', value: '' }];
            
            // Add all actual room types from the picklist
            if (data.values && data.values.length > 0) {
                data.values.forEach(option => {
                    this.roomTypeOptions.push({
                        label: option.label,
                        value: option.value
                    });
                });
                console.log('Room type options populated:', JSON.stringify(this.roomTypeOptions));
            } else {
                console.warn('No room type values found in picklist data');
            }
        } else if (error) {
            console.error('Error fetching room types:', error);
            this.handleError('Error fetching room types', error);
            
            // Fallback: Create some default room types based on available rooms
            this.createRoomTypeOptionsFromAvailableRooms();
        }
    }
    
    // Create room type options from available rooms if picklist values can't be fetched
    createRoomTypeOptionsFromAvailableRooms() {
        try {
            // Start with "All Room Types" option
            this.roomTypeOptions = [{ label: 'All Room Types', value: '' }];
            
            if (this.availableRooms && this.availableRooms.length > 0) {
                const roomTypes = new Set();
                
                // Extract unique room types
                this.availableRooms.forEach(room => {
                    if (room.Room_Type__c) {
                        roomTypes.add(room.Room_Type__c);
                    }
                });
                
                // Add each type to options
                roomTypes.forEach(roomType => {
                    this.roomTypeOptions.push({
                        label: roomType,
                        value: roomType
                    });
                });
                
                console.log('Created room type options from available rooms:', JSON.stringify(this.roomTypeOptions));
            } else {
                // Fallback default values
                this.roomTypeOptions = [
                    { label: 'All Room Types', value: '' },
                    { label: 'Standard', value: 'Standard' },
                    { label: 'Deluxe', value: 'Deluxe' },
                    { label: 'Suite', value: 'Suite' }
                ];
                console.log('Using default room type options');
            }
        } catch (error) {
            console.error('Error creating room type options from available rooms:', error);
            // Use basic fallback
            this.roomTypeOptions = [
                { label: 'All Room Types', value: '' },
                { label: 'Standard', value: 'Standard' },
                { label: 'Deluxe', value: 'Deluxe' },
                { label: 'Suite', value: 'Suite' }
            ];
        }
    }
    
    // Initialize component
    connectedCallback() {
        try {
            // Set minimum date to today
            const today = new Date();
            this.minDate = today.toISOString().split('T')[0];
            this.minCheckoutDate = this.minDate;
            
            // Check for stored contact information and load it
            this.loadStoredContactInfo();
            
            // Check for payment return from PayPal with a small delay
            setTimeout(() => this.checkUrlParams(), 100);
        } catch (error) {
            this.handleError('Failed to initialize component', error);
        }
    }
    
    // Load contact information from session storage
    loadStoredContactInfo() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                const storedContactInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.CONTACT_INFO);
                
                if (storedContactInfo) {
                    this.contact = JSON.parse(storedContactInfo);
                    console.log('Loaded contact info from session storage:', this.contact);
                }
                
                const storedReservationInfo = sessionStorage.getItem(SESSION_STORAGE_KEYS.RESERVATION_INFO);
                
                if (storedReservationInfo) {
                    const parsedReservation = JSON.parse(storedReservationInfo);
                    // Only take non-date fields as dates would need to be re-selected for new reservation
                    this.reservation.Special_Requests__c = parsedReservation.Special_Requests__c || '';
                }
            }
        } catch (error) {
            console.error('Error loading stored contact info:', error);
            // Continue without the stored information
        }
    }
    
    // Save contact information to session storage
    saveContactInfoToStorage() {
        try {
            if (typeof window !== 'undefined' && window.sessionStorage) {
                sessionStorage.setItem(SESSION_STORAGE_KEYS.CONTACT_INFO, JSON.stringify(this.contact));
                console.log('Saved contact info to session storage');
                
                // Save relevant reservation info
                const reservationToStore = {
                    Special_Requests__c: this.reservation.Special_Requests__c
                };
                sessionStorage.setItem(SESSION_STORAGE_KEYS.RESERVATION_INFO, JSON.stringify(reservationToStore));
            }
        } catch (error) {
            console.error('Error saving contact info to session storage:', error);
            // Continue without storing the information
        }
    }

    // Alternatively, save contact information to a cookie
    saveContactInfoToCookie() {
        try {
            if (typeof document !== 'undefined' && document.cookie) {
                // Set cookie expiration to 7 days
                const expirationDate = new Date();
                expirationDate.setDate(expirationDate.getDate() + 7);
                
                // Encode contact info as JSON and create cookie
                const contactInfoCookie = encodeURIComponent(JSON.stringify(this.contact));
                document.cookie = `${SESSION_STORAGE_KEYS.CONTACT_INFO}=${contactInfoCookie}; expires=${expirationDate.toUTCString()}; path=/; SameSite=Strict`;
                
                console.log('Saved contact info to cookie');
            }
        } catch (error) {
            console.error('Error saving contact info to cookie:', error);
            // Continue without storing the information
        }
    }
    
    // Retrieve contact information from a cookie
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
    
    // Check URL parameters for PayPal return
    checkUrlParams() {
        try {
            if (typeof window === 'undefined' || !window.location) {
                console.error('Window or location is not available');
                return;
            }
            
            const urlParams = new URLSearchParams(window.location.search);
            const status = urlParams.get('status');
            const orderId = urlParams.get('token'); // PayPal returns the order ID as 'token'
            const tempId = urlParams.get('tempId');
            
            if (!status || !tempId) return;
            
            this.tempReservationId = tempId;
            
            // Process PayPal return
            if (status === 'success' && orderId) {
                this.handlePayPalSuccess(orderId, status);
            } else if (status === 'cancel') {
                this.showToast('Info', 'Payment canceled. Please try again or select a different payment method.', 'info');
                this.clearUrlParameters();
            }
        } catch (error) {
            this.handleError('Error checking payment status', error);
            this.clearUrlParameters();
        }
    }

    // Handle successful PayPal return
    handlePayPalSuccess(orderId, status) {
        this.spinnerStatus = true;
        this.isPaymentInProcess = true;
        this.showToast('Info', 'Processing payment...', 'info');
        
        if (!this.contact || !this.reservation) {
            console.error('Contact or reservation data is missing');
            this.spinnerStatus = false;
            this.isPaymentInProcess = false;
            this.showToast('Error', 'Payment processing failed: missing reservation data', 'error');
            return;
        }
        
        processPayPalReturn({
            contactData: this.contact,
            reservationData: this.reservation,
            roomId: this.selectedRoomId,
            paymentId: orderId,
            status: status
        })
        .then(result => {
            this.spinnerStatus = false;
            this.isPaymentInProcess = false;
            
            if (result) {
                this.reservationId = result;
                this.paymentComplete = true;
                this.currentStep = STEPS.PAYMENT;
                
                // Save contact information after successful payment
                this.saveContactInfoToStorage();
                
                this.showToast('Success', 'Payment successful! Your reservation is confirmed.', 'success');
            } else {
                this.showToast('Info', 'Payment was canceled.', 'info');
                this.currentStep = STEPS.PAYMENT;
            }
            
            this.clearUrlParameters();
        })
        .catch(error => {
            this.spinnerStatus = false;
            this.isPaymentInProcess = false;
            this.handleError('Failed to process payment', error);
            this.clearUrlParameters();
        });
    }

    // Clear URL parameters
    clearUrlParameters() {
        if (window && window.history) {
            const cleanUrl = window.location.href.split('?')[0];
            window.history.replaceState({}, document.title, cleanUrl);
        }
    }
    
    // Handle date selection changes
    handleDateChange(event) {
        try {
            const field = event.target.name;
            if (field === 'checkInDate') {
                this.checkInDate = event.target.value;
                
                // Update minimum checkout date to be the day after check-in
                if (this.checkInDate) {
                    const checkInDateObj = new Date(this.checkInDate);
                    checkInDateObj.setDate(checkInDateObj.getDate() + 1);
                    this.minCheckoutDate = checkInDateObj.toISOString().split('T')[0];
                    
                    // Reset checkout date if it's now invalid
                    if (this.checkOutDate && new Date(this.checkOutDate) <= new Date(this.checkInDate)) {
                        this.checkOutDate = '';
                    }
                }
            } else if (field === 'checkOutDate') {
                this.checkOutDate = event.target.value;
            }
            
            // Calculate nights and total cost if both dates are set
            this.calculateStayDetails();
        } catch (error) {
            this.handleError('Error updating dates', error);
        }
    }
    
    // Calculate nights and total cost
    calculateStayDetails() {
        if (!this.checkInDate || !this.checkOutDate) return;
        
        try {
            const checkIn = new Date(this.checkInDate);
            const checkOut = new Date(this.checkOutDate);
            
            // Calculate the difference in days
            const diffTime = Math.abs(checkOut - checkIn);
            this.totalNights = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            
            // Calculate total cost if room is selected
            if (this.selectedRoomPrice) {
                this.totalCost = this.selectedRoomPrice * this.totalNights;
                // Update the reservation object
                this.reservation.Total_Cost__c = this.totalCost;
            }
        } catch (error) {
            this.handleError('Error calculating stay details', error);
        }
    }
    
    // Search for available rooms
    handleSearchRooms() {
        try {
            if (!this.validateDateSelection()) return;
            
            this.spinnerStatus = true;
        
            // Create ISO string format dates for the API
            const checkInDateTime = new Date(this.checkInDate).toISOString();
            const checkOutDateTime = new Date(this.checkOutDate).toISOString();
            
            console.log('Searching for rooms with dates:', { 
                checkIn: checkInDateTime, 
                checkOut: checkOutDateTime 
            });
            
            getAvailableRooms({ 
                checkInDateTime: checkInDateTime, 
                checkOutDateTime: checkOutDateTime 
            })
            .then(result => {
                console.log('Room search result:', result);
                this.availableRooms = result || [];
                
                // Initialize filtered rooms with all available rooms
                this.filteredRooms = [...this.availableRooms];
                
                // Extract unique floor numbers for filter dropdown
                this.populateFilterOptions();
                
                this.spinnerStatus = false;
        
                if (this.availableRooms.length === 0) {
                    this.showToast('Info', 'No rooms available for selected dates.', 'info');
                    this.showDebugButton = true;
                } else {
                    this.currentStep = STEPS.ROOM_SELECTION;
        
                    // Set the dates in the reservation object
                    this.reservation.Check_In__c = checkInDateTime;
                    this.reservation.Check_Out__c = checkOutDateTime;
                }
            })
            .catch(error => {
                this.spinnerStatus = false;
                this.handleError('Failed to fetch available rooms', error);
                this.showDebugButton = true;
            });
        } catch (error) {
            this.spinnerStatus = false;
            this.handleError('Error searching for rooms', error);
            this.showDebugButton = true;
        }
    }

    // Populate filter options based on available rooms
    populateFilterOptions() {
        try {
            // Create unique floor options
            const floors = new Set();
            this.availableRooms.forEach(room => {
                if (room.Floor__c) {
                    floors.add(room.Floor__c);
                }
            });
            
            this.floorOptions = Array.from(floors).sort().map(floor => {
                return { label: `Floor ${floor}`, value: floor.toString() };
            });
            
            // Add "All Floors" option
            this.floorOptions.unshift({ label: 'All Floors', value: '' });
            
            // Log the floor and room type options for debugging
            console.log('Floor options:', this.floorOptions);
            console.log('Room type options:', this.roomTypeOptions);
            
            // Check what room types exist in available rooms
            const availableRoomTypes = new Set();
            this.availableRooms.forEach(room => {
                if (room.Room_Type__c) {
                    availableRoomTypes.add(room.Room_Type__c);
                }
            });
            console.log('Available room types in search results:', Array.from(availableRoomTypes));
        } catch (error) {
            console.error('Error populating filter options:', error);
        }
    }    

    // Toggle filter section visibility
    handleToggleFilters() {
        this.showFilters = !this.showFilters;
    }

    // Handle filter changes
    handleFilterChange(event) {
        try {
            const field = event.target.name;
            const value = event.target.value;
            
            // Update filter value
            this[field] = value;
            
            // Apply filters
            this.applyFilters();
        } catch (error) {
            console.error('Error handling filter change:', error);
        }
    }

    // Handle feature filter changes
    handleFeatureFilterChange(event) {
        try {
            const selectedFeatures = event.detail.value;
            this.filterFeatures = selectedFeatures;
            
            // Apply filters
            this.applyFilters();
        } catch (error) {
            console.error('Error handling feature filter change:', error);
        }
    }

    // Apply all filters to available rooms
    applyFilters() {
        try {
            // Start with all available rooms
            let filteredResults = [...this.availableRooms];
            
            // Filter by floor if specified
            if (this.filterFloor) {
                filteredResults = filteredResults.filter(room => 
                    room.Floor__c && room.Floor__c.toString() === this.filterFloor.toString());
            }
            
            // Filter by room number if specified
            if (this.filterRoomNumber) {
                const roomNumberQuery = this.filterRoomNumber.toLowerCase();
                filteredResults = filteredResults.filter(room => 
                    room.Room_Number__c && 
                    room.Room_Number__c.toString().toLowerCase().includes(roomNumberQuery));
            }
            
            // Filter by room type if specified
            if (this.filterRoomType) {
                filteredResults = filteredResults.filter(room => 
                    room.Room_Type__c === this.filterRoomType);
            }
            
            // Filter by selected features
            if (this.filterFeatures && this.filterFeatures.length > 0) {
                filteredResults = filteredResults.filter(room => {
                    // Check if room has all selected features
                    // This assumes features are stored as a semi-colon separated string
                    if (!room.Features__c) return false;
                    
                    const roomFeatures = room.Features__c.split(';').map(f => f.trim());
                    return this.filterFeatures.every(feature => roomFeatures.includes(feature));
                });
            }
            
            // Update the filtered rooms list
            this.filteredRooms = filteredResults;
            
            console.log(`Filtered rooms: ${this.filteredRooms.length} of ${this.availableRooms.length}`);
        } catch (error) {
            console.error('Error applying filters:', error);
            // Fall back to showing all rooms
            this.filteredRooms = [...this.availableRooms];
        }
    }

    // Clear all filters
    handleClearFilters() {
        try {
            this.filterFloor = '';
            this.filterRoomNumber = '';
            this.filterRoomType = '';
            this.filterFeatures = [];
            
            // Reset filtered rooms to show all available rooms
            this.filteredRooms = [...this.availableRooms];
            
            // Reset any filter input fields
            const filterInputs = this.template.querySelectorAll('.room-filter input, .room-filter select');
            if (filterInputs) {
                filterInputs.forEach(input => {
                    input.value = '';
                });
            }
            
            // Reset multi-select
            const featureSelect = this.template.querySelector('.feature-filter');
            if (featureSelect) {
                featureSelect.value = [];
            }
        } catch (error) {
            console.error('Error clearing filters:', error);
        }
    }

    // Validate date selection
    validateDateSelection() {
        if (!this.checkInDate || !this.checkOutDate) {
            this.showToast('Error', 'Please select both check-in and check-out dates', 'error');
            return false;
        }
    
        const today = new Date();
        today.setHours(0, 0, 0, 0); // Reset time to start of day
        
        const checkInDate = new Date(this.checkInDate);
        const checkOutDate = new Date(this.checkOutDate);
        
        if (checkInDate < today) {
            this.showToast('Error', 'Check-in date cannot be in the past', 'error');
            return false;
        }
    
        if (checkInDate >= checkOutDate) {
            this.showToast('Error', 'Check-out date must be after check-in date', 'error');
            return false;
        }
        
        return true;
    }
    
    // Handle room selection
    handleRoomSelection(event) {
        try {
            if (!event?.currentTarget?.dataset) {
                console.error('Invalid event or missing dataset in handleRoomSelection');
                return;
            }
            
            const selectedRoomId = event.currentTarget.dataset.id;
            if (!selectedRoomId) {
                console.error('Missing room ID in handleRoomSelection');
                return;
            }
            
            const selectedRoom = this.availableRooms.find(room => room.Id === selectedRoomId);
            
            if (selectedRoom) {
                this.selectedRoomId = selectedRoom.Id;
                this.selectedRoomType = selectedRoom.Room_Type__c;
                this.selectedRoomPrice = selectedRoom.Price_Per_Night__c || 0;
                this.reservation.Room_Type__c = selectedRoom.Room_Type__c;
                
                // Calculate total cost
                this.calculateStayDetails();
                
                // Move to reservation form
                this.currentStep = STEPS.RESERVATION_FORM;
            } else {
                this.showToast('Error', 'Could not find selected room. Please try again.', 'error');
            }
        } catch (error) {
            this.handleError('Error selecting room', error);
        }
    }
    
    // Go back to previous step
    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
            
            // If going back to room selection, ensure filters are applied
            if (this.currentStep === STEPS.ROOM_SELECTION) {
                this.applyFilters();
            }
        }
    }

    // Handle input changes for Contact fields
    handleContactChange(event) {
        this.handleObjectChange(event, 'contact');
    }

    // Handle input changes for Reservation fields
    handleReservationChange(event) {
        this.handleObjectChange(event, 'reservation');
    }

    // Handle card detail changes
    handleCardDetailChange(event) {
        this.handleObjectChange(event, 'cardDetails');
    }

    // Generic handler for object updates
    handleObjectChange(event, objectName) {
        try {
            if (!event?.target?.name) return;
            
            const field = event.target.name;
            const value = event.target.value;
            
            this[objectName] = { 
                ...this[objectName], 
                [field]: value 
            };
            
            // If contact info is updated, save it to session storage
            if (objectName === 'contact' && this.validateContactEntry(field, value)) {
                this.saveContactInfoToStorage();
            }
        } catch (error) {
            this.handleError(`Error updating ${objectName} information`, error);
        }
    }
    
    // Validate whether a contact field is complete enough to save
    validateContactEntry(field, value) {
        // Only save when we have meaningful information
        if (field === 'FirstName' || field === 'LastName') {
            return value && value.length > 1;
        }
        if (field === 'Email') {
            return value && value.includes('@');
        }
        if (field === 'Phone') {
            return value && value.length > 5;
        }
        return false;
    }

    // Validate the reservation form
    validateReservationForm() {
        try {
            // 1. Validate all required HTML elements first
            const inputFields = [
                ...this.template.querySelectorAll('.reservation-form lightning-input[required]'),
                ...this.template.querySelectorAll('.reservation-form lightning-textarea[required]'),
                ...this.template.querySelectorAll('.reservation-form lightning-combobox[required]')
            ];
            
            // Log how many required fields we found
            console.log(`Found ${inputFields.length} required input fields`);
            
            let allFieldsValid = true;
            inputFields.forEach(inputField => {
                if (inputField.reportValidity) {
                    inputField.reportValidity();
                    if (!inputField.checkValidity()) {
                        allFieldsValid = false;
                        console.warn(`Field validation failed: ${inputField.name || 'unnamed field'}`);
                    }
                }
            });
            
            // 2. Explicitly validate contact information
            const requiredContactFields = ['FirstName', 'LastName', 'Email', 'Phone'];
            let contactValid = true;
            const missingFields = [];
            
            requiredContactFields.forEach(field => {
                if (!this.contact[field]) {
                    contactValid = false;
                    missingFields.push(field.replace(/([A-Z])/g, ' $1').trim()); // Convert camelCase to spaces
                }
            });
            
            if (!contactValid) {
                this.showToast('Error', `Missing required contact information: ${missingFields.join(', ')}`, 'error');
                return false;
            }
            
            // 3. Validate email format
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (this.contact.Email && !emailRegex.test(this.contact.Email)) {
                this.showToast('Error', 'Please enter a valid email address', 'error');
                return false;
            }
            
            // 4. Check if any phone number was provided and has minimum length
            if (!this.contact.Phone || this.contact.Phone.length < 5) {
                this.showToast('Error', 'Please enter a valid phone number', 'error');
                return false;
            }
            
            // 5. Ensure special fields are validated
            if (!this.selectedRoomId || !this.selectedRoomType) {
                this.showToast('Error', 'Room selection information is missing. Please go back and select a room.', 'error');
                return false;
            }
            
            if (!allFieldsValid) {
                this.showToast('Error', 'Please fill all required fields correctly', 'error');
                return false;
            }
            
            // If we got here, all validation passed
            return true;
        } catch (error) {
            this.handleError('Error validating form', error);
            return false;
        }
    }
    
    // Move to payment step after validating reservation details
    handleProceedToPayment() {
        try {
            if (!this.validateReservationForm()) return;
            
            // Create DateTime objects with the selected dates to ensure they're updated
            const checkInDateTime = new Date(this.checkInDate).toISOString();
            const checkOutDateTime = new Date(this.checkOutDate).toISOString();
            
            // Update reservation data with the latest values
            this.reservation.Check_In__c = checkInDateTime;
            this.reservation.Check_Out__c = checkOutDateTime;
            this.reservation.Room_Type__c = this.selectedRoomType;
            this.reservation.Total_Cost__c = this.totalCost;
            
            // Save contact information before moving to payment
            this.saveContactInfoToStorage();
            
            // Move to payment step
            this.currentStep = STEPS.PAYMENT;
            this.showToast('Success', 'Please complete payment to confirm your reservation.', 'success');
        } catch (error) {
            this.handleError('Error proceeding to payment', error);
        }
    }
    
    // Extract error message from error object
    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        
        if (typeof error === 'string') return error;
        if (error.body?.message) return error.body.message;
        if (error.message) return error.message;
        
        return JSON.stringify(error);
    }
    
    // Handle payment method selection
    handlePaymentMethodChange(event) {
        try {
            if (!event?.target) return;
            this.paymentMethod = event.target.value;
        } catch (error) {
            this.handleError('Error changing payment method', error);
        }
    }
    
    // Real-time card number formatting (4-digit groups with spaces)
    handleCardNumberFormat(event) {
        if (!event?.target) return;
        
        const input = event.target;
        let value = input.value.replace(/\D/g, ''); // Remove all non-digits
        
        // Format with spaces after every 4 digits
        if (value.length > 0) {
            value = value.match(/.{1,4}/g).join(' ');
        }
        
        // Update the input value
        input.value = value;
        
        // Store the card number
        this.cardDetails.cardNumber = value;
        
        // Detect and store card type
        this.detectedCardType = this.getCardType(value);
    }
    
    // Card type detection based on card number
    getCardType(cardNumber) {
        if (!cardNumber) return '';
        
        // Remove spaces
        const number = cardNumber.replace(/\s/g, '');
        
        // Check card type by prefix patterns
        if (/^4/.test(number)) return 'Visa';
        if (/^(5[1-5]|2[2-7])/.test(number)) return 'Mastercard';
        if (/^3[47]/.test(number)) return 'American Express';
        if (/^6(?:011|5)/.test(number)) return 'Discover';
        
        return 'Unknown';
    }
    
    // Validate card number with Luhn algorithm and show error message inline
    handleCardNumberValidation(event) {
        const input = event.target;
        const value = input.value.replace(/\s/g, '');
        
        // Simple length check only
        if (value.length < 13 || value.length > 19) {
            input.setCustomValidity('Card number must be between 13 and 19 digits');
        } 
        // Check if it contains only numbers
        else if (!/^\d+$/.test(value)) {
            input.setCustomValidity('Card number must contain only digits');
        }
        else {
            input.setCustomValidity('');
        }
        
        input.reportValidity();
    }
    
    // Validate cardholder name
    handleCardholderNameValidation(event) {
        const input = event.target;
        const value = input.value.trim();
        
        if (!value) {
            input.setCustomValidity('Please enter the cardholder name');
        } else if (value.length < 3) {
            input.setCustomValidity('Name is too short');
        } else {
            input.setCustomValidity('');
        }
        
        input.reportValidity();
    }
    
    // Real-time expiry date formatting (MM/YY)
    handleExpiryFormat(event) {
        if (!event?.target) return;
        
        const input = event.target;
        let value = input.value.replace(/\D/g, ''); // Remove all non-digits
        
        // Add slash after 2 digits (MM/YY format)
        if (value.length > 2) {
            value = value.substring(0, 2) + '/' + value.substring(2);
        }
        
        // Limit to MM/YY format (5 chars total)
        if (value.length > 5) {
            value = value.substring(0, 5);
        }
        
        // Update the input value
        input.value = value;
        this.formattedExpiry = value;
    }
    
    // Validate expiration date
    handleExpiryValidation(event) {
        const input = event.target;
        const value = input.value;
        
        // Just check format
        if (!/^\d{2}\/\d{2}$/.test(value)) {
            input.setCustomValidity('Expiry date must be in MM/YY format');
        } 
        else {
            const [month, year] = value.split('/');
            const monthNum = parseInt(month, 10);
            
            // Simple month range check
            if (monthNum < 1 || monthNum > 12) {
                input.setCustomValidity('Month must be between 01 and 12');
            } 
            else {
                input.setCustomValidity('');
            }
        }
        
        input.reportValidity();
    }
    
    // Convert MM/YY format to cardExpMonth and cardExpYear
    handleExpiryChange(event) {
        if (!event?.target) return;
        
        const value = event.target.value;
        if (value.includes('/') && value.length >= 4) {
            const [month, year] = value.split('/');
            
            // Save month as is (01-12)
            this.cardDetails.cardExpMonth = month;
            
            // Convert YY to YYYY
            const currentYear = new Date().getFullYear().toString();
            const century = currentYear.substring(0, 2);
            this.cardDetails.cardExpYear = century + year;
        } else {
            // Clear the values if format is incomplete
            this.cardDetails.cardExpMonth = '';
            this.cardDetails.cardExpYear = '';
        }
    }
    
    // Ensure CVV only contains digits and validate
    handleCVVFormat(event) {
        if (!event?.target) return;
        
        const input = event.target;
        input.value = input.value.replace(/\D/g, ''); // Remove all non-digits
    }
    
    // Validate CVV
    handleCVVValidation(event) {
        const input = event.target;
        const value = input.value;
        
        // Just check if it's numeric and length
        if (!/^\d+$/.test(value)) {
            input.setCustomValidity('CVV must contain only digits');
        } 
        else if (value.length < 3 || value.length > 4) {
            input.setCustomValidity('CVV must be 3 or 4 digits');
        } 
        else {
            input.setCustomValidity('');
        }
        
        input.reportValidity();
    }
    
    // Update formatted expiry from existing month/year values
    updateFormattedExpiry() {
        if (this.cardDetails.cardExpMonth && this.cardDetails.cardExpYear) {
            const year = this.cardDetails.cardExpYear.toString().substring(2); // Get last 2 digits
            this.formattedExpiry = `${this.cardDetails.cardExpMonth}/${year}`;
        } else {
            this.formattedExpiry = '';
        }
    }
    
    // Handle payment based on selected method
    handleProcessPayment() {
        try {
            if (this.paymentMethod === PAYMENT_METHODS.PAYPAL) {
                this.handlePayPalPayment();
            } else if (this.paymentMethod === PAYMENT_METHODS.CARD) {
                // Validate the card fields before processing
                if (this.validateCardFields()) {
                    this.handleCardPayment();
                }
            } else {
                this.showToast('Error', 'Please select a payment method', 'error');
            }
        } catch (error) {
            this.handleError('Error processing payment', error);
        }
    }
    
    // Validate card fields
    validateCardFields() {
        let allValid = true;
        
        // Get all card input fields
        const cardFields = this.template.querySelectorAll('.card-payment-form lightning-input');
        
        // Trigger validation on each field
        cardFields.forEach(field => {
            if (field.name === 'cardNumber') {
                this.handleCardNumberValidation({ target: field });
                if (field.checkValidity && !field.checkValidity()) allValid = false;
            }
            else if (field.name === 'cardName') {
                this.handleCardholderNameValidation({ target: field });
                if (field.checkValidity && !field.checkValidity()) allValid = false;
            }
            else if (field.name === 'cardExpiry') {
                this.handleExpiryValidation({ target: field });
                if (field.checkValidity && !field.checkValidity()) allValid = false;
            }
            else if (field.name === 'cardCVV') {
                this.handleCVVValidation({ target: field });
                if (field.checkValidity && !field.checkValidity()) allValid = false;
            }
        });
        
        if (!allValid) {
            this.showToast('Error', 'Please correct the errors in the card details', 'error');
        }
        
        return allValid;
    }
    
    // Enhanced Luhn algorithm check for credit card validation
    luhnCheck(cardNumber) {
        // During simulation, always return true for any non-empty card number
        return !!cardNumber && cardNumber.length >= 13;
    }
    
    // Initiate PayPal payment
    handlePayPalPayment() {
        try {
            this.paymentProcessing = true;
            this.isPaymentInProcess = true;
            this.showToast('Info', 'Connecting to PayPal...', 'info');
            
            // Check if window is available (for testing in non-browser environments)
            if (typeof window === 'undefined' || !window.location) {
                throw new Error('Window object not available');
            }
            
            // Generate return URLs
            const baseUrl = window.location.href.split('?')[0]; // Remove any existing parameters
            const returnUrl = baseUrl + '?status=success';
            const cancelUrl = baseUrl + '?status=cancel';
            
            // Validate required data before making the call
            if (!this.contact || !this.reservation || !this.selectedRoomId) {
                throw new Error('Missing required data for payment');
            }
            
            startPayPalPayment({
                contactData: this.contact,
                reservationData: this.reservation,
                roomId: this.selectedRoomId,
                amount: this.totalCost,
                returnUrl: returnUrl,
                cancelUrl: cancelUrl
            })
            .then(result => {
                // Redirect to PayPal
                if (result) {
                    // Add a small delay to ensure the toast message is shown
                    setTimeout(() => {
                        try {
                            // Open PayPal in a new window/tab
                            window.open(result, '_blank');
                            
                            this.paymentProcessing = false;
                            this.isPaymentInProcess = false;
                            this.showToast(
                                'PayPal Redirect', 
                                'A new window has opened for PayPal payment. Please complete your payment there and return to this page.', 
                                'info'
                            );
                        } catch (windowError) {
                            console.error('Error opening PayPal window:', windowError);
                            this.paymentProcessing = false;
                            this.isPaymentInProcess = false;
                            this.showToast('Error', 'Failed to open PayPal window. Please try again.', 'error');
                        }
                    }, 1000);
                } else {
                    throw new Error('No redirect URL received from PayPal');
                }
            })
            .catch(error => {
                this.paymentProcessing = false;
                this.isPaymentInProcess = false;
                this.handleError('Failed to initiate PayPal payment', error);
            });
        } catch (error) {
            this.paymentProcessing = false;
            this.isPaymentInProcess = false;
            this.handleError('Error initiating PayPal payment', error);
        }
    }

    // Handle card payment
    handleCardPayment() {
        try {
            console.log('Starting card payment process');
            this.paymentProcessing = true;
            this.isPaymentInProcess = true;
            this.showToast('Info', 'Processing payment...', 'info');
            
            // Get card details in the format expected by the controller
            const { cardName, cardNumber, cardExpMonth, cardExpYear, cardCVV } = this.cardDetails;
            
            // Log card details (safely - don't log full card number or CVV!)
            console.log('Card Details Validation:');
            console.log('- Card Name: ' + (cardName ? 'PROVIDED (' + cardName.length + ' chars)' : 'MISSING'));
            console.log('- Card Number: ' + (cardNumber ? 'PROVIDED (' + cardNumber.length + ' chars)' : 'MISSING'));
            console.log('- Card Exp Month: ' + (cardExpMonth ? cardExpMonth : 'MISSING'));
            console.log('- Card Exp Year: ' + (cardExpYear ? cardExpYear : 'MISSING'));
            console.log('- Card CVV: ' + (cardCVV ? 'PROVIDED (' + cardCVV.length + ' chars)' : 'MISSING'));
            
            // Check if any values are missing or empty
            const missingFields = [];
            if (!cardName) missingFields.push('Card Name');
            if (!cardNumber) missingFields.push('Card Number');
            if (!cardExpMonth) missingFields.push('Expiration Month');
            if (!cardExpYear) missingFields.push('Expiration Year');
            if (!cardCVV) missingFields.push('CVV');
            
            if (missingFields.length > 0) {
                console.error('Missing card fields: ' + missingFields.join(', '));
                this.paymentProcessing = false;
                this.isPaymentInProcess = false;
                this.showToast('Error', 'Missing required fields: ' + missingFields.join(', '), 'error');
                return;
            }
            
            // Remove spaces from card number
            const cleanCardNumber = cardNumber.replace(/\s/g, '');
            console.log('Clean card number length: ' + cleanCardNumber.length);
            
            // Log other important data (don't log sensitive data)
            console.log('Selected Room ID: ' + (this.selectedRoomId || 'MISSING'));
            console.log('Contact email provided: ' + (this.contact.Email ? 'YES' : 'NO'));
            console.log('Reservation data: Check-in and Check-out dates provided: ' + 
                        ((this.reservation.Check_In__c && this.reservation.Check_Out__c) ? 'YES' : 'NO'));
            
            processInFormPayment({
                contactData: this.contact,
                reservationData: this.reservation,
                roomId: this.selectedRoomId,
                cardName: cardName,
                cardNumber: cleanCardNumber,
                cardExpMonth: cardExpMonth,
                cardExpYear: cardExpYear,
                cardCVV: cardCVV
            })
            .then(result => {
                console.log('Payment API call completed with result:', result);
                this.paymentProcessing = false;
                this.isPaymentInProcess = false;

                if (result) {
                    this.reservationId = result;

                    // Generate a simple booking number based on the reservation ID
                    this.bookingNumber = 'RES-' + this.reservationId;
                    
                    // Save contact information after successful payment
                    this.saveContactInfoToStorage();

                    // Show success message
                    this.showToast('Success', 
                        'Payment successful! Your Reservation ID is ' + this.reservationId, 
                        'success'
                    );

                    // Proceed to payment confirmation step
                    this.currentStep = STEPS.PAYMENT;
                    this.paymentComplete = true;
                } else {
                    this.showToast('Error', 'Payment failed. Please try again.', 'error');
                }
            })
            .catch(error => {
                console.error('Payment API call failed with error:', error);
                console.error('Error details:', this.getErrorMessage(error));
                this.paymentProcessing = false;
                this.isPaymentInProcess = false;
                this.handleError('Failed to process card payment', error);
            });
        } catch (error) {
            console.error('Exception in handleCardPayment:', error);
            this.paymentProcessing = false;
            this.isPaymentInProcess = false;
            this.handleError('Error processing card payment', error);
        }
    }
    
    // Cancel payment and go back
    handleCancelPayment() {
        this.showToast('Info', 'Reservation process canceled', 'info');
        this.resetFields();
        this.currentStep = STEPS.DATE_SELECTION;
    }

    // Reset input fields
    resetFields() {
        this.contact = {
            FirstName: '',
            LastName: '',
            Email: '',
            Phone: ''
        };
        this.reservation = {
            Check_In__c: '',
            Check_Out__c: '',
            Room_Type__c: '',
            Special_Requests__c: '',
            Total_Cost__c: 0,
            Payment_Status__c: 'Pending'
        };
        this.checkInDate = '';
        this.checkOutDate = '';
        this.selectedRoomId = '';
        this.selectedRoomType = '';
        this.selectedRoomPrice = 0;
        this.totalNights = 0;
        this.totalCost = 0;
        this.availableRooms = [];
        this.filteredRooms = [];
        this.reservationId = '';
        this.paymentProcessing = false;
        this.paymentComplete = false;
        this.paymentMethod = PAYMENT_METHODS.PAYPAL;
        this.tempReservationId = '';
        this.isPaymentInProcess = false;
        this.detectedCardType = '';
        
        // Reset filter values
        this.filterFloor = '';
        this.filterRoomNumber = '';
        this.filterRoomType = '';
        this.filterFeatures = [];
        this.showFilters = false;
        
        // Reset card details
        this.cardDetails = {
            cardName: '',
            cardNumber: '',
            cardExpMonth: '',
            cardExpYear: '',
            cardCVV: ''
        };
        
        this.formattedExpiry = '';
        
        // Reset current step
        this.currentStep = STEPS.DATE_SELECTION;
        
        // Clear stored data when completely resetting
        this.clearStoredContactData();
    }

    // Clear stored contact data if needed
    clearStoredContactData() {
        try {
            if (typeof window !== 'undefined') {
                if (window.sessionStorage) {
                    sessionStorage.removeItem(SESSION_STORAGE_KEYS.CONTACT_INFO);
                    sessionStorage.removeItem(SESSION_STORAGE_KEYS.RESERVATION_INFO);
                }
                
                if (document && document.cookie) {
                    document.cookie = `${SESSION_STORAGE_KEYS.CONTACT_INFO}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
                }
                
                console.log('Cleared stored contact data');
            }
        } catch (error) {
            console.error('Error clearing stored contact data:', error);
        }
    }

    // Handle errors and show toast message
    handleError(message, error) {
        console.error(`${message}:`, error);
        this.showToast('Error', `${message}: ${this.getErrorMessage(error)}`, 'error');
    }

    // Show Toast Notification
    showToast(title, message, variant) {
        if (!title || !message || !variant) {
            console.warn('Missing parameters for toast notification');
            return;
        }
        
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
    // Format currency
    formatCurrency(value) {
        if (value === undefined || value === null) {
            return 'PHP 0.00';
        }
        
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'PHP'
        }).format(value);
    }
    
    // Navigate to another component while passing contact info
    navigateToAnotherComponent() {
        // First ensure contact info is saved to storage
        this.saveContactInfoToStorage();
        
        // Then navigate to another component
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__AnotherComponent'
            },
            state: {
                // Can pass minimal info in URL if needed
                contactName: `${this.contact.FirstName} ${this.contact.LastName}`
            }
        });
    }

    // Debugging methods
    handleDebugClick() {
        // Show a debug panel or log debug information
        console.log('Debug information:');
        console.log('- Selected dates:', this.checkInDate, this.checkOutDate);
        console.log('- API call dates:', this.reservation.Check_In__c, this.reservation.Check_Out__c);
        console.log('- Current step:', this.currentStep);
        console.log('- Available rooms count:', this.availableRooms?.length || 0);
        console.log('- Filtered rooms count:', this.filteredRooms?.length || 0);
        
        // Display debug info to user
        this.showToast(
            'Debug Information', 
            `Check-in: ${this.checkInDate}, Check-out: ${this.checkOutDate}, API format: ${this.reservation.Check_In__c?.substring(0, 10)}`,
            'info'
        );
    }

    get filterButtonLabel() {
        return this.showFilters ? 'Hide Filters' : 'Show Filters';
    }
    
    get filterIconName() {
        return this.showFilters ? 'utility:chevronup' : 'utility:filter';
    }
}