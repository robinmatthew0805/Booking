import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class HotelManagementActions extends LightningElement {
    @track checkOutDate = '';
    @track minCheckoutDate = '';
    @track showUpdateDate = false;
    
    connectedCallback() {
        try {
            // Set minimum date to today
            const today = new Date();
            this.minDate = today.toISOString().split('T')[0];
            this.minCheckoutDate = this.minDate;
            
        } catch (error) {
            this.handleError('Failed to initialize component', error);
        }
    }
    
    handleUpdateReservation() {
        // this.showToast('Update Reservation', 'This would open a form to update reservations', 'info');

        this.showUpdateDate = true;
    }
    
    handleUpdateRoomPrice() {
        this.showToast('Update Room Price', 'This would open a form to update room pricing', 'info');
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
            this.updateCheckOut();
        } catch (error) {
            this.handleError('Error updating dates', error);
        }
    }

    updateCheckOut(){

    }

    
}