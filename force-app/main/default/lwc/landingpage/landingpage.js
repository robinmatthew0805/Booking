import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LandingPage extends LightningElement {
    @track emailValue = '';
    
    // Handle email input change
    handleEmailChange(event) {
        this.emailValue = event.target.value;
    }
    
    // Handle early access subscription
    handleSubscribe() {
        if (!this.emailValue || !this.validateEmail(this.emailValue)) {
            this.showToast('Error', 'Please enter a valid email address', 'error');
            return;
        }
        
        // In a real app, you would send this to your backend
        console.log('Email submitted:', this.emailValue);
        this.showToast('Success', 'Thanks for your interest in CloudStay!', 'success');
        this.emailValue = '';
    }
    
    // Simple email validation
    validateEmail(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    }
    
    // Show toast notification
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    
    // Navigate to booking
    navigateToBooking() {
        // Would normally navigate to booking page
        console.log('Navigating to booking page');
        this.showToast('Coming Soon', 'Booking functionality will be available soon!', 'info');
    }
    
    // Navigate to social media
    navigateToSocial(event) {
        const social = event.currentTarget.dataset.social;
        console.log('Social media clicked:', social);
        
        // Would normally open in a new tab
        this.showToast('Social Media', `${social} page coming soon!`, 'info');
    }
}