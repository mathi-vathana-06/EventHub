public without sharing class EventCatalogController {

    public List<Event__c> openEvents { get; set; }
    public Boolean isLoggedIn { get; set; }
    public Contact loggedInContact { get; set; }
    public Integer totalRecordsFound { get; set; }
    
    public String serializedCategoriesPassed { get; set; }
    public String serializedPricesPassed { get; set; }
    public String serializedCitiesPassed { get; set; }

    public EventCatalogController() {
        this.isLoggedIn = false;
        this.totalRecordsFound = 0;
        
        String contactSessionId = ApexPages.currentPage().getParameters().get('contactId');
        if (String.isNotBlank(contactSessionId)) {
            List<Contact> activeSession = [
                SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id = :contactSessionId.trim() LIMIT 1
            ];
            if (!activeSession.isEmpty()) {
                this.loggedInContact = activeSession[0];
                this.isLoggedIn = true;
            }
        }
        
        loadDefaultCatalogData();
    }

    
    public PageReference goToMyAccountPageFromCatalog() {
        PageReference pr = new PageReference('/EventHub/apex/EventMyAccount');
        if (this.loggedInContact != null) {
            pr.getParameters().put('contactId', this.loggedInContact.Id);
        }
        pr.setRedirect(true);
        return pr;
    }

    public void loadDefaultCatalogData() {
        this.openEvents = [
            SELECT Id, Name, Start_Date__c, Venue__c, Category__c, Registration_Fee__c, Seats_Remaining__c, Banner_URL__c 
            FROM Event__c 
            WHERE Start_Date__c >= TODAY 
            ORDER BY Start_Date__c ASC 
            LIMIT 20
        ];
        this.totalRecordsFound = this.openEvents.size();
    }

    public void processAndExecuteFilters() {
        String baseQuery = 'SELECT Id, Name, Start_Date__c, Venue__c, Category__c, Registration_Fee__c, Seats_Remaining__c, Banner_URL__c FROM Event__c WHERE Start_Date__c >= TODAY';
        
        if (String.isNotBlank(serializedCategoriesPassed)) {
            List<String> selectedCats = serializedCategoriesPassed.split(',');
            baseQuery += ' AND Category__c IN :selectedCats';
        }
        
        if (String.isNotBlank(serializedPricesPassed)) {
            List<String> selectedPrices = serializedPricesPassed.split(',');
            if (selectedPrices.size() == 1) {
                if (selectedPrices[0] == 'Free') {
                    baseQuery += ' AND (Registration_Fee__c = 0 OR Registration_Fee__c = null)';
                } else if (selectedPrices[0] == 'Paid') {
                    baseQuery += ' AND Registration_Fee__c > 0';
                }
            }
        }
        
        if (String.isNotBlank(serializedCitiesPassed)) {
            List<String> selectedCities = serializedCitiesPassed.split(',');
            baseQuery += ' AND (';
            for (Integer i = 0; i < selectedCities.size(); i++) {
                if (i > 0) baseQuery += ' OR ';
                baseQuery += ' Venue__c LIKE \'%' + String.escapeSingleQuotes(selectedCities[i].trim()) + '%\'';
            }
            baseQuery += ')';
        }
        
        baseQuery += ' ORDER BY Start_Date__c ASC LIMIT 20';
        this.openEvents = Database.query(baseQuery);
        this.totalRecordsFound = this.openEvents.size();
    }
}