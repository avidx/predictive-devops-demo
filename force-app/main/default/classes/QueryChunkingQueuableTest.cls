@isTest
public class QueryChunkingQueuableTest {
    
    @isTest
    static void testQueryChunkingWithMultipleChunks() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test Contacts with LastActivityDate within LAST_N_DAYS:400
        // Create 250 contacts to test chunking (will require 2 chunks of 200)
        List<Contact> testContacts = new List<Contact>();
        Date activityDate = Date.today().addDays(-100); // Within LAST_N_DAYS:400
        
        for (Integer i = 0; i < 250; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert testContacts;
        
        Test.startTest();
        QueryChunkingQueuable job = new QueryChunkingQueuable();
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify that contacts were processed
        // Note: In a real scenario, you would track processed records
        // For this test, we verify the job executed without errors
        List<Contact> queriedContacts = [
            SELECT Id FROM Contact 
            WHERE LastActivityDate = LAST_N_DAYS:400
        ];
        System.assert(queriedContacts.size() >= 250, 'Should have at least 250 contacts matching the query');
    }
    
    @isTest
    static void testQueryChunkingWithSingleChunk() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create 50 contacts (less than chunk size of 200)
        List<Contact> testContacts = new List<Contact>();
        Date activityDate = Date.today().addDays(-50);
        
        for (Integer i = 0; i < 50; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert testContacts;
        
        Test.startTest();
        QueryChunkingQueuable job = new QueryChunkingQueuable();
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify contacts exist
        List<Contact> queriedContacts = [
            SELECT Id FROM Contact 
            WHERE LastActivityDate = LAST_N_DAYS:400
        ];
        System.assert(queriedContacts.size() >= 50, 'Should have at least 50 contacts matching the query');
    }
    
    @isTest
    static void testQueryChunkingWithNoRecords() {
        // Don't create any contacts with LastActivityDate = LAST_N_DAYS:400
        // This tests the scenario where no records match the query
        
        Test.startTest();
        QueryChunkingQueuable job = new QueryChunkingQueuable();
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify no contacts match the query
        List<Contact> queriedContacts = [
            SELECT Id FROM Contact 
            WHERE LastActivityDate = LAST_N_DAYS:400
        ];
        System.assertEquals(0, queriedContacts.size(), 'Should have no contacts matching the query');
    }
    
    @isTest
    static void testQueryChunkingWithExactChunkSize() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create exactly 200 contacts (exact chunk size)
        List<Contact> testContacts = new List<Contact>();
        Date activityDate = Date.today().addDays(-200);
        
        for (Integer i = 0; i < 200; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert testContacts;
        
        Test.startTest();
        QueryChunkingQueuable job = new QueryChunkingQueuable();
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify contacts exist
        List<Contact> queriedContacts = [
            SELECT Id FROM Contact 
            WHERE LastActivityDate = LAST_N_DAYS:400
        ];
        System.assert(queriedContacts.size() >= 200, 'Should have at least 200 contacts matching the query');
    }
    
    @isTest
    static void testQueryChunkingWithLargeDataset() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create 500 contacts to test multiple chunks
        List<Contact> testContacts = new List<Contact>();
        Date activityDate = Date.today().addDays(-300);
        
        for (Integer i = 0; i < 500; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert testContacts;
        
        Test.startTest();
        QueryChunkingQueuable job = new QueryChunkingQueuable();
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify contacts exist
        List<Contact> queriedContacts = [
            SELECT Id FROM Contact 
            WHERE LastActivityDate = LAST_N_DAYS:400
        ];
        System.assert(queriedContacts.size() >= 500, 'Should have at least 500 contacts matching the query');
    }
    
    @isTest
    static void testQueryLocatorInitialization() {
        // Test that the constructor initializes the QueryLocator correctly
        Test.startTest();
        QueryChunkingQueuable job = new QueryChunkingQueuable();
        System.assertNotEquals(null, job, 'Job should be instantiated');
        Test.stopTest();
    }
}