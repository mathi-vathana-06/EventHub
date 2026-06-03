public without sharing class EventBookingEngine {

    // Properties for Database Listings (Shared across Home views)
    public List<Event__c> openEvents { get; set; }
    public String homeSearchKey { get; set; }
    
    // Auth Session State Variables (Strictly Contact standard object mapping)
    public Boolean isLoggedIn { get; set; }
    public Contact loggedInContact { get; set; }
    
    // Properties for My Account View List
    public List<Registration__c> myRegisteredEvents { get; set; }
    
    // Properties for Page 3 (Event Detail View)
    public Event__c selectedEvent { get; set; }
    
    // PROPERTIES: Keeps Page 1 Layout Elements perfectly safe
    public String selectedCategory { get; set; }
    public String selectedPriceRange { get; set; }
    public String selectedCity { get; set; }
    public String catalogSortOrder { get; set; }
    public Integer totalRecordsFound { get; set; }
    
    // Login Screen Form Field Bindings
    public String loginEmail { get; set; }
    public String loginPassword { get; set; } 
    
    // Registration Screen Form Field Bindings
    public String regFirstName { get; set; }
    public String regLastName { get; set; }
    public String regEmail { get; set; }
    public String regPhone { get; set; }
    public String regPassword { get; set; } 

    // Constructor: Initializes context maps and checks standard contact session parameters
    public EventBookingEngine() {
        homeSearchKey = '';
        isLoggedIn = false;
        
        this.myRegisteredEvents = new List<Registration__c>();
        
        selectedCategory = 'All';
        selectedPriceRange = 'All';
        selectedCity = 'All';
        catalogSortOrder = 'Start_Date__c ASC';
        totalRecordsFound = 0;
        
        String searchParam = ApexPages.currentPage().getParameters().get('searchKey');
        if (String.isNotBlank(searchParam)) {
            this.homeSearchKey = searchParam.trim();
        }
        
        String contactSessionId = ApexPages.currentPage().getParameters().get('contactId');
        if (String.isNotBlank(contactSessionId)) {
            List<Contact> activeSession = [
                SELECT Id, FirstName, LastName, Email, Phone, Department 
                FROM Contact 
                WHERE Id = :contactSessionId.trim() 
                LIMIT 1
            ];
            if (!activeSession.isEmpty()) {
                this.loggedInContact = activeSession[0];
                this.isLoggedIn = true;
                loadStudentRegistrations();
            }
        }
        
        executeDynamicCatalogQuery();
    }

    // DATABASE QUERY ENGINE: Fetches actual registered events for the logged-in student
    public void loadStudentRegistrations() {
        if (this.loggedInContact != null) {
            this.myRegisteredEvents = [
                SELECT Id, Name, Status__c, 
                       Event__r.Id, Event__r.Name, 
                       Event__r.Start_Date__c, Event__r.Venue__c
                FROM Registration__c
                WHERE Registrant_Profile__c = :this.loggedInContact.Id
                ORDER BY Event__r.Start_Date__c ASC
            ];
        }
    }

    
    public PageReference goToMyAccountPage() {
        PageReference pr = new PageReference('/EventHub/apex/EventMyAccount');
        if (this.loggedInContact != null) {
            pr.getParameters().put('contactId', this.loggedInContact.Id);
        }
        pr.setRedirect(true);
        return pr;
    }

    // Dynamic Database Query Engine: Filters records for the homepage grid block
    public void executeDynamicCatalogQuery() {
        String baseQuery = 'SELECT Id, Name, Start_Date__c, Venue__c, Registration_Fee__c, Seats_Remaining__c, Banner_URL__c FROM Event__c WHERE Start_Date__c >= TODAY';
        
        if (String.isNotBlank(selectedCategory) && selectedCategory != 'All') {
            baseQuery += ' AND Category__c = :selectedCategory';
        }
        if (selectedPriceRange == 'Free') {
            baseQuery += ' AND (Registration_Fee__c = 0 OR Registration_Fee__c = null)';
        } else if (selectedPriceRange == 'Paid') {
            baseQuery += ' AND Registration_Fee__c > 0';
        }
        if (String.isNotBlank(selectedCity) && selectedCity != 'All') {
            baseQuery += ' AND Venue__c LIKE \'%' + String.escapeSingleQuotes(selectedCity) + '%\'';
        }
        
        if (String.isNotBlank(homeSearchKey)) {
            String cleanSearch = '%' + String.escapeSingleQuotes(homeSearchKey.trim()) + '%';
            baseQuery += ' AND (Name LIKE :cleanSearch OR Venue__c LIKE :cleanSearch)';
        }
        
        baseQuery += ' ORDER BY ' + catalogSortOrder;
        baseQuery += ' LIMIT 15';
        
        openEvents = Database.query(baseQuery);
        totalRecordsFound = openEvents.size();
    }

    public void handleHomeSearch() {
        executeDynamicCatalogQuery();
    }

    public PageReference loginUser() {
        ApexPages.getMessages().clear();
        if (String.isBlank(loginEmail) || String.isBlank(loginPassword)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please enter both your Email and Password.'));
            return null;
        }

        List<Contact> records = [
            SELECT Id, FirstName, LastName, Email, Phone, Portal_Password__c 
            FROM Contact 
            WHERE Email = :loginEmail.trim() 
            LIMIT 1
        ];

        if (records.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Account not found. Please register below.'));
            return null;
        }

        Contact foundContact = records[0];
        if (String.isBlank(foundContact.Portal_Password__c) || foundContact.Portal_Password__c != loginPassword.trim()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Incorrect password.'));
            return null;
        }

        PageReference storefrontPage = new PageReference('/EventHub/apex/EventHome');
        storefrontPage.getParameters().put('contactId', foundContact.Id);
        storefrontPage.setRedirect(true);
        return storefrontPage;
    }

    public PageReference registerUser() {
        ApexPages.getMessages().clear();
        if (String.isBlank(regEmail) || String.isBlank(regFirstName) || String.isBlank(regLastName) || String.isBlank(regPassword)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'All fields are mandatory.'));
            return null;
        }

        Integer existingCount = [SELECT Count() FROM Contact WHERE Email = :regEmail.trim()];
        if (existingCount > 0) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Email already registered.'));
            return null;
        }

        Contact freshContact = new Contact(
            FirstName = regFirstName.trim(),
            LastName = regLastName.trim(),
            Email = regEmail.trim(),
            Phone = String.isNotBlank(regPhone) ? regPhone.trim() : '',
            Portal_Password__c = regPassword.trim()
        );

        try {
            insert freshContact;
            PageReference storefrontPage = new PageReference('/EventHub/apex/EventHome');
            storefrontPage.getParameters().put('contactId', freshContact.Id);
            storefrontPage.setRedirect(true);
            return storefrontPage;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Registration error: ' + e.getMessage()));
            return null;
        }
    }

    public PageReference logout() {
        this.isLoggedIn = false;
        this.loggedInContact = null;
        this.myRegisteredEvents.clear();
        this.homeSearchKey = '';
        PageReference logoutRedirect = new PageReference('/EventHub/apex/EventLogin');
        logoutRedirect.setRedirect(true);
        return logoutRedirect;
    }
}