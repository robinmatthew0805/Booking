import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getUpcomingReservations from '@salesforce/apex/HotelDataController.getUpcomingReservations';
import getTodayCheckIns from '@salesforce/apex/HotelDataController.getTodayCheckIns';
import getTodayCheckOuts from '@salesforce/apex/HotelDataController.getTodayCheckOuts';
import searchReservations from '@salesforce/apex/HotelDataController.searchReservations';
import searchGuests from '@salesforce/apex/HotelDataController.searchGuests';
import updateReservationStatus from '@salesforce/apex/HotelDataController.updateReservationStatus';

// Row action definitions
const RESERVATION_ACTIONS = [
    { label: 'View Details', name: 'view' }
];

export default class HotelManagementDashboard extends NavigationMixin(LightningElement) {
    // Track active tab
    @track activeTab = 'reservations';
    
    // Data variables
    @track upcomingReservations = [];
    @track checkIns = [];
    @track checkOuts = [];
    @track searchResults = [];
    
    // Loading states
    @track isLoading = false;
    @track isSearching = false;
    
    // Search parameters
    @track searchType = 'reservation';
    @track searchTerm = '';
    @track dateFrom = null;
    @track dateTo = null;
    
    // Wired apex results for refreshing
    wiredReservationsResult;
    wiredCheckInsResult;
    wiredCheckOutsResult;

    // Column definitions for lightning-datatable
    upcomingReservationsColumns = [
        { label: 'Booking Number', fieldName: 'Booking_Number__c', type: 'text' },
        { label: 'Guest Name', fieldName: 'GuestName', type: 'text' },
        { 
            label: 'Check-In', 
            fieldName: 'Check_In__c', 
            type: 'date', 
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        { 
            label: 'Check-out', 
            fieldName: 'Check_out__c', 
            type: 'date', 
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        { label: 'Room', fieldName: 'RoomName', type: 'text' },
        { label: 'Room Type', fieldName: 'Room_Type__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Payment', fieldName: 'Payment_Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: { rowActions: RESERVATION_ACTIONS }
        }
    ];
    
    checkInsColumns = [
        { label: 'Booking Number', fieldName: 'Booking_Number__c', type: 'text' },
        { label: 'Guest Name', fieldName: 'GuestName', type: 'text' },
        { label: 'Room', fieldName: 'RoomName', type: 'text' },
        { 
            label: 'Check-In Time', 
            fieldName: 'Check_In__c', 
            type: 'date', 
            typeAttributes: {
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: { rowActions: RESERVATION_ACTIONS }
        }
    ];
    
    checkOutsColumns = [
        { label: 'Booking Number', fieldName: 'Booking_Number__c', type: 'text' },
        { label: 'Guest Name', fieldName: 'GuestName', type: 'text' },
        { label: 'Room', fieldName: 'RoomName', type: 'text' },
        { 
            label: 'Check-Out Time', 
            fieldName: 'Check_out__c', 
            type: 'date', 
            typeAttributes: {
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: { rowActions: RESERVATION_ACTIONS }
        }
    ];
    
    searchResultsColumns = [
        { label: 'Booking Number', fieldName: 'Booking_Number__c', type: 'text' },
        { label: 'Guest Name', fieldName: 'GuestName', type: 'text' },
        { 
            label: 'Check-In', 
            fieldName: 'Check_In__c', 
            type: 'date', 
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        { 
            label: 'Check-out', 
            fieldName: 'Check_out__c', 
            type: 'date', 
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        { label: 'Room', fieldName: 'RoomName', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: { rowActions: RESERVATION_ACTIONS }
        }
    ];
    
    guestSearchResultsColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Phone', fieldName: 'Phone', type: 'phone' },
        {
            type: 'action',
            typeAttributes: { rowActions: RESERVATION_ACTIONS }
        }
    ];
    
    // Fetch data from Apex
    @wire(getUpcomingReservations)
    wiredUpcomingReservations(result) {
        this.wiredReservationsResult = result;
        if (result.data) {
            this.upcomingReservations = this.formatReservationsData(result.data);
        } else if (result.error) {
            this.handleError(result.error);
        }
    }
    
    @wire(getTodayCheckIns)
    wiredCheckIns(result) {
        this.wiredCheckInsResult = result;
        if (result.data) {
            this.checkIns = this.formatReservationsData(result.data);
        } else if (result.error) {
            this.handleError(result.error);
        }
    }
    
    @wire(getTodayCheckOuts)
    wiredCheckOuts(result) {
        this.wiredCheckOutsResult = result;
        if (result.data) {
            this.checkOuts = this.formatReservationsData(result.data);
        } else if (result.error) {
            this.handleError(result.error);
        }
    }
    
    // Format data for display
    formatReservationsData(data) {
        return data.map(item => {
            return {
                ...item,
                GuestName: item.Guest_Name__r ? item.Guest_Name__r.Name : '',
                RoomName: item.Room__r ? item.Room__r.Name : ''
            };
        });
    }
    
    // Tab handling
    handleTabSelect(event) {
        this.activeTab = event.currentTarget.dataset.tabId;
        
        // Update tab styles
        const tabItems = this.template.querySelectorAll('.slds-tabs_default__item');
        tabItems.forEach(item => {
            const link = item.querySelector('.slds-tabs_default__link');
            const isSelected = link.dataset.tabId === this.activeTab;
            
            if (isSelected) {
                item.classList.add('slds-is-active');
            } else {
                item.classList.remove('slds-is-active');
            }
            
            link.setAttribute('aria-selected', isSelected);
            link.setAttribute('tabindex', isSelected ? '0' : '-1');
        });
    }
    
    // Handle row actions - view only
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        if (action.name === 'view') {
            this.viewRecordDetails(row);
        }
    }
    
    // View record details - UPDATED to use NavigationMixin
    viewRecordDetails(row) {
        // Get the record ID based on the row data and current tab/search type
        let recordId = row.Id;
        let objectApiName = this.determineObjectApiName(row);
        
        if (recordId) {
            // Navigate to the record detail page
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: objectApiName,
                    actionName: 'view'
                }
            });
        } else {
            this.showToast('Error', 'Record ID not found', 'error');
        }
    }
    
    // Helper method to determine the object API name based on the row data
    determineObjectApiName(row) {
        // Determine the object type based on available fields
        if (this.searchType === 'guest') {
            return 'Contact'; // Assuming guests are stored as Contacts
        } else if (row.Booking_Number__c !== undefined) {
            return 'Reservation__c'; // Assuming this is the API name for reservations
        } else {
            // Default case or fallback
            return 'Reservation__c';
        }
    }
    
    // Search handling
    handleSearchTypeChange(event) {
        this.searchType = event.target.value;
    }
    
    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }
    
    handleDateFromChange(event) {
        this.dateFrom = event.target.value;
    }
    
    handleDateToChange(event) {
        this.dateTo = event.target.value;
    }
    
    handleClearSearch() {
        this.searchTerm = '';
        this.dateFrom = null;
        this.dateTo = null;
        this.searchResults = [];
        
        // Reset form fields
        this.template.querySelectorAll('input').forEach(input => {
            input.value = '';
        });
    }
    
    handleSearch() {
        if (!this.searchTerm && !this.dateFrom && !this.dateTo) {
            this.showToast('Error', 'Please enter at least one search criterion', 'error');
            return;
        }
        
        this.isSearching = true;
        
        if (this.searchType === 'reservation') {
            searchReservations({
                searchTerm: this.searchTerm,
                fromDate: this.dateFrom,
                toDate: this.dateTo
            })
            .then(result => {
                this.searchResults = this.formatReservationsData(result);
                this.isSearching = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isSearching = false;
            });
        } else if (this.searchType === 'guest') {
            searchGuests({
                searchTerm: this.searchTerm
            })
            .then(result => {
                this.searchResults = result;
                this.isSearching = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isSearching = false;
            });
        }
    }
    
    // Error handling
    handleError(error) {
        console.error('Error:', error);
        this.showToast('Error', error.body ? error.body.message : 'An error occurred', 'error');
    }
    
    // Toast message helper
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    // Refresh the data on the current tab
    handleRefresh() {
        this.isLoading = true;
        
        // Refresh the appropriate data based on the active tab
        if (this.activeTab === 'reservations') {
            refreshApex(this.wiredReservationsResult);
        } else if (this.activeTab === 'checkinout') {
            refreshApex(this.wiredCheckInsResult);
            refreshApex(this.wiredCheckOutsResult);
        } else if (this.activeTab === 'search' && this.searchResults.length > 0) {
            // Re-execute the search to refresh search results
            this.handleSearch();
        }
        
        this.isLoading = false;
    }
    
    // Getters for conditional rendering
    get reservationsTabStyle() {
        return this.activeTab === 'reservations' ? 'display:block;' : 'display:none;';
    }
    
    get checkinoutTabStyle() {
        return this.activeTab === 'checkinout' ? 'display:block;' : 'display:none;';
    }
    
    get searchTabStyle() {
        return this.activeTab === 'search' ? 'display:block;' : 'display:none;';
    }
    
    get hasUpcomingReservations() {
        return this.upcomingReservations && this.upcomingReservations.length > 0;
    }
    
    get hasCheckIns() {
        return this.checkIns && this.checkIns.length > 0;
    }
    
    get hasCheckOuts() {
        return this.checkOuts && this.checkOuts.length > 0;
    }
    
    get hasSearchResults() {
        return this.searchResults && this.searchResults.length > 0;
    }
    
    get currentSearchResultsColumns() {
        return this.searchType === 'guest' ? this.guestSearchResultsColumns : this.searchResultsColumns;
    }
}