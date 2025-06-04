import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPromotions from '@salesforce/apex/HotelDataController.getPromotions';
import searchPromotions from '@salesforce/apex/HotelDataController.searchPromotions';

export default class HotelPromotions extends LightningElement {
    @track promos = [];
    @track promoName = '';
    @track targetCustomer = '';
    @track activeDate = null;
    @track isSearching = false;
    @track filteredPromos = [];

    // Wire method to fetch promotions
    @wire(getPromotions)
    wiredPromos({ error, data }) {
        this.isLoadingPromos = true;
        if (data) {
            this.promos = data;
            this.filteredPromos = data;
            this.promosError = undefined;
        } else if (error) {
            this.promosError = error;
            this.promos = [];
            this.filteredPromos = [];
            this.showToast('Error', 'Error loading promotions: ' + this.reduceErrors(error), 'error');
        }
        this.isLoadingPromos = false;
    }

    // Getters for template conditionals
    get hasPromos() {
        return this.filteredPromos && this.filteredPromos.length > 0;
    }

    // Promo management handlers
    handleCreatePromo() {
        this.showToast('Create Promotion', 'This would open a form to create a new promotion', 'info');
    }

    handleViewPromo(event) {
        const promoId = event.currentTarget.dataset.id;
        this.showToast('View Promotion', `This would display detailed information for promotion ${promoId}`, 'info');
    }

    handleEditPromo(event) {
        const promoId = event.currentTarget.dataset.id;
        this.showToast('Edit Promotion', `This would open a form to edit promotion ${promoId}`, 'info');
    }

    handleDeletePromo(event) {
        const promoId = event.currentTarget.dataset.id;
        this.showToast('Delete Promotion', `This would confirm deletion of promotion ${promoId}`, 'warning');
    }

    // Search handlers
    handlePromoNameChange(event) {
        this.promoName = event.target.value;
    }

    handleTargetCustomerChange(event) {
        this.targetCustomer = event.target.value;
    }

    handleActiveDateChange(event) {
        this.activeDate = event.target.value;
    }

    handleClearPromoSearch() {
        this.promoName = '';
        this.targetCustomer = '';
        this.activeDate = null;
        this.filteredPromos = this.promos;
        
        // Reset form inputs
        const inputFields = this.template.querySelectorAll('input');
        inputFields.forEach(input => {
            input.value = '';
        });
        
        // Reset select field
        const selectField = this.template.querySelector('select');
        if (selectField) {
            selectField.value = '';
        }
    }

    handleSearchPromos() {
        // Show loading spinner
        this.isSearching = true;
        
        // If no filters applied, show all promos
        if (!this.promoName && !this.targetCustomer && !this.activeDate) {
            this.filteredPromos = this.promos;
            this.isSearching = false;
            return;
        }
        
        // Convert activeDate string to Date object for Apex
        const searchDate = this.activeDate ? new Date(this.activeDate) : null;
        
        // Call Apex search method
        searchPromotions({
            promoName: this.promoName,
            targetCustomer: this.targetCustomer,
            activeDate: searchDate
        })
        .then(result => {
            this.filteredPromos = result;
            this.showToast('Search Complete', `Found ${this.filteredPromos.length} promotions`, 'success');
        })
        .catch(error => {
            this.showToast('Search Error', this.reduceErrors(error), 'error');
            this.filteredPromos = [];
        })
        .finally(() => {
            this.isSearching = false;
        });
    }

    // Helper method to show toast notifications
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant, // info, success, warning, error
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
    
    // Error formatting helper method
    reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }
        
        return errors
            .filter(error => !!error)
            .map(error => {
                // UI API read errors
                if (Array.isArray(error.body)) {
                    return error.body.map(e => e.message).join(', ');
                }
                // Page level errors
                else if (error.pageErrors && error.pageErrors.length) {
                    return error.pageErrors.map(e => e.message).join(', ');
                }
                // Field level errors
                else if (error.fieldErrors && Object.keys(error.fieldErrors).length) {
                    const fieldErrors = [];
                    Object.values(error.fieldErrors).forEach(errorArray => {
                        fieldErrors.push(...errorArray.map(e => e.message));
                    });
                    return fieldErrors.join(', ');
                }
                // Single error string/message
                else if (typeof error.body.message === 'string') {
                    return error.body.message;
                }
                // Default
                return error.message || JSON.stringify(error);
            })
            .join(', ');
    }
}