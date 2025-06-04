// guestPromoViewer.js
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex method
import getActivePromotions from '@salesforce/apex/PromoController.getActivePromotions';
import getRoomTypes from '@salesforce/apex/PromoController.getRoomTypes';

export default class PromoAdvertisements extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track promotions = [];
    @track filteredPromotions = [];
    @track selectedRoomType = '';
    @track roomTypeOptions = [];
    @track noPromotionsAvailable = false;
    
    // Load promotions on component initialization
    connectedCallback() {
        this.loadPromotions();
        this.loadRoomTypes();
    }
    
    // Load room types for filtering
    loadRoomTypes() {
        getRoomTypes()
            .then(result => {
                // Create an "All Room Types" option
                this.roomTypeOptions = [
                    { label: 'All Room Types', value: '' }
                ];
                
                // Add room types from the result
                result.forEach(type => {
                    this.roomTypeOptions.push({
                        label: type,
                        value: type
                    });
                });
            })
            .catch(error => {
                this.handleError(error);
            });
    }
    
    // Load active promotions
    loadPromotions() {
        this.isLoading = true;
        
        getActivePromotions()
            .then(result => {
                if (result && result.length > 0) {
                    // Process promotion data
                    this.promotions = result.map(promo => ({
                        id: promo.Id,
                        promoName: promo.Promo_Name__c,
                        discountPercentage: promo.Discount_Percentage__c,
                        discountPercentageFormatted: parseInt(promo.Discount_Percentage__c) + '%',
                        startDate: promo.Start_Date__c,
                        startDateFormatted: this.formatDate(promo.Start_Date__c),
                        endDate: promo.End_Date__c,
                        endDateFormatted: this.formatDate(promo.End_Date__c),
                        roomTypes: promo.Applicable_Room_Types__c ? promo.Applicable_Room_Types__c.split(';') : [],
                        roomTypesDisplay: promo.Applicable_Room_Types__c ? promo.Applicable_Room_Types__c.replace(/;/g, ', ') : '',
                        targetCustomers: promo.Target_Customers__c,
                        additionalDetails: promo.Additional_Details__c
                    }));
                    
                    // Initialize filtered promotions with all promotions
                    this.filteredPromotions = [...this.promotions];
                    this.noPromotionsAvailable = false;
                } else {
                    this.promotions = [];
                    this.filteredPromotions = [];
                    this.noPromotionsAvailable = true;
                }
                
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }
    
    // Format date for display
    formatDate(dateString) {
        if (!dateString) return '';
        
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return new Date(dateString).toLocaleDateString('en-US', options);
    }
    
    // Handle room type filter change
    handleRoomTypeFilter(event) {
        this.selectedRoomType = event.detail.value;
        this.filterPromotions();
    }
    
    // Filter promotions based on selected room type
    filterPromotions() {
        if (!this.selectedRoomType) {
            // If no room type is selected, show all promotions
            this.filteredPromotions = [...this.promotions];
        } else {
            // Filter promotions by selected room type
            this.filteredPromotions = this.promotions.filter(promo => 
                promo.roomTypes.includes(this.selectedRoomType)
            );
        }
        
        // Update no promotions flag
        this.noPromotionsAvailable = this.filteredPromotions.length === 0;
    }
    
    // Handle "Book Now" button click
    handleBookNow(event) {
        const promoId = event.target.dataset.id;
        const selectedPromo = this.promotions.find(promo => promo.id === promoId);
        
        if (selectedPromo) {
            // Navigate to the reservation page with promotion ID
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'Make_Reservation__c'
                },
                state: {
                    promoId: promoId
                }
            });
        }
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
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: errorMessage,
                variant: 'error'
            })
        );
    }
}