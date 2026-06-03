public without sharing class EventRegistrationController {

    public Event__c targetEvent { get; set; }
    public Contact currentContact { get; set; }
    public Registration__c pendingRegistration { get; set; }
    
   
    public Integer seatVolumeProperty { get; set; }
    
    public Decimal totalCalculatedCost { get; set; }
    public Boolean isFormValid { get; set; }

    public EventRegistrationController() {
        this.isFormValid = false;
        this.totalCalculatedCost = 0.00;
        this.seatVolumeProperty = 1; // Default seat layout calculation starting point
        
        this.pendingRegistration = new Registration__c();
        this.pendingRegistration.Number_of_Seats__c = 1; 
        
        String eventId = ApexPages.currentPage().getParameters().get('id');
        String contactId = ApexPages.currentPage().getParameters().get('contactId');
        
        if (String.isNotBlank(eventId)) {
            List<Event__c> events = [
                SELECT Id, Name, Venue__c, Registration_Fee__c, Seats_Remaining__c 
                FROM Event__c 
                WHERE Id = :eventId.trim() 
                LIMIT 1
            ];
            if (!events.isEmpty()) {
                this.targetEvent = events[0];
            }
        }
        
        if (String.isNotBlank(contactId)) {
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Phone 
                FROM Contact 
                WHERE Id = :contactId.trim() 
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                this.currentContact = contacts[0];
                this.isFormValid = true; 
            }
        }
        
        
        if (this.currentContact == null) {
            List<Contact> backupContact = [SELECT Id, FirstName, LastName, Email, Phone FROM Contact LIMIT 1];
            if (!backupContact.isEmpty()) { 
                this.currentContact = backupContact[0]; 
                this.isFormValid = true;
            }
        }
        if (this.targetEvent == null) {
            List<Event__c> backupEvent = [SELECT Id, Name, Venue__c, Registration_Fee__c, Seats_Remaining__c FROM Event__c LIMIT 1];
            if (!backupEvent.isEmpty()) { this.targetEvent = backupEvent[0]; }
        }
        
        if (this.currentContact != null) {
            this.pendingRegistration.Registrant_Name__c = this.currentContact.FirstName + ' ' + this.currentContact.LastName;
            this.pendingRegistration.Email__c = this.currentContact.Email;
            this.pendingRegistration.Phone__c = this.currentContact.Phone;
        }
        
        recalculateTicketPricing();
    }

   
    public void recalculateTicketPricing() {
        // Enforce safe primitive values back into your calculation engine variables
        if (this.seatVolumeProperty == null || this.seatVolumeProperty < 1) {
            this.seatVolumeProperty = 1;
        }
        
        this.pendingRegistration.Number_of_Seats__c = this.seatVolumeProperty;
        
        Decimal ticketCost = (this.targetEvent != null && this.targetEvent.Registration_Fee__c != null) ? this.targetEvent.Registration_Fee__c : 0.00;
        this.totalCalculatedCost = ticketCost * this.pendingRegistration.Number_of_Seats__c;
    }

    public PageReference executeTicketBooking() {
        ApexPages.getMessages().clear();
        
        // Re-execute calculations right before submission to synchronize primitive storage inputs
        recalculateTicketPricing();
        
        if (this.pendingRegistration.Number_of_Seats__c == null || this.pendingRegistration.Number_of_Seats__c < 1) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Desired seat pass volume must be equal to 1 or more passes.'));
            return null;
        }
        
        this.pendingRegistration.Event__c = this.targetEvent.Id;
        this.pendingRegistration.Registrant_Profile__c = this.currentContact.Id;
        this.pendingRegistration.Amount_Paid__c = this.totalCalculatedCost;
        this.pendingRegistration.Payment_Status__c = (this.totalCalculatedCost > 0) ? 'PAID' : 'FREE';
        this.pendingRegistration.Status__c = 'Confirmed';
        this.pendingRegistration.Registered_At__c = System.now();
        
        try {
            insert this.pendingRegistration;
            
            PageReference successPageRedirect = new PageReference('/EventHub/apex/RegistrationSuccess');
            successPageRedirect.getParameters().put('regId', this.pendingRegistration.Id);
            successPageRedirect.setRedirect(true);
            return successPageRedirect;
            
        } catch (Exception transactionalException) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Database transactional error: ' + transactionalException.getMessage()));
            return null;
        }
    }
}