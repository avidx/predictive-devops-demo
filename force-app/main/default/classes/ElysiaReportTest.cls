/**
 * Test class for Elysia__c custom object.
 * Validates record creation, field assignment, and lookups (Account, Contact, Lead).
 */
@isTest
private class ElysiaReportTest {

    @isTest
    static void testCreateElysiaReportFromLead() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'ElysiaLead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert testLead;

        Test.startTest();
        Elysia__c report = new Elysia__c(
            Lead__c = testLead.Id,
            Origin__c = 'Lead',
            Type__c = 'Elysia Report',
            Elysia_Report_Date__c = System.now(),
            Elysia_RequestId__c = 'req-001',
            Elysia_Response__c = 'ok',
            Elysia_Report__c = '<p>Sample report content</p>'
        );
        insert report;
        Test.stopTest();

        report = [SELECT Id, Name, Lead__c, Origin__c, Type__c, Elysia_Report_Date__c, Elysia_RequestId__c, Elysia_Response__c FROM Elysia__c WHERE Id = :report.Id];
        System.assertNotEquals(null, report.Id, 'Elysia record should be created');
        System.assertEquals(testLead.Id, report.Lead__c, 'Lead lookup should match');
        System.assertEquals('Lead', report.Origin__c, 'Origin should be Lead');
        System.assertEquals('Elysia Report', report.Type__c, 'Type should be Elysia Report');
        System.assertEquals('req-001', report.Elysia_RequestId__c, 'RequestId should match');
    }

    @isTest
    static void testCreateElysiaReportFromAccount() {
        Account testAccount = new Account(Name = 'Elysia Test Account');
        insert testAccount;

        Test.startTest();
        Elysia__c report = new Elysia__c(
            Account__c = testAccount.Id,
            Origin__c = 'Account',
            Type__c = 'Elysia Report'
        );
        insert report;
        Test.stopTest();

        report = [SELECT Id, Account__c, Origin__c FROM Elysia__c WHERE Id = :report.Id];
        System.assertEquals(testAccount.Id, report.Account__c, 'Account lookup should match');
        System.assertEquals('Account', report.Origin__c, 'Origin should be Account');
    }

    @isTest
    static void testCreateElysiaReportFromContact() {
        Account acc = new Account(Name = 'Contact Test Account');
        insert acc;
        Contact con = new Contact(FirstName = 'Elysia', LastName = 'Contact', AccountId = acc.Id);
        insert con;

        Test.startTest();
        Elysia__c report = new Elysia__c(
            Contact__c = con.Id,
            Account__c = acc.Id,
            Origin__c = 'Contact',
            Type__c = 'Elysia Report'
        );
        insert report;
        Test.stopTest();

        report = [SELECT Id, Contact__c, Account__c, Origin__c FROM Elysia__c WHERE Id = :report.Id];
        System.assertEquals(con.Id, report.Contact__c, 'Contact lookup should match');
        System.assertEquals('Contact', report.Origin__c, 'Origin should be Contact');
    }

    @isTest
    static void testCreateElysiaReportFromOpportunity() {
        Account acc = new Account(Name = 'Opp Test Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Elysia Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        Elysia__c report = new Elysia__c(
            Account__c = acc.Id,
            Origin__c = 'Opportunity',
            Type__c = 'Elysia Report'
        );
        insert report;
        Test.stopTest();

        report = [SELECT Id, Account__c, Origin__c FROM Elysia__c WHERE Id = :report.Id];
        System.assertEquals(acc.Id, report.Account__c, 'Account lookup should match');
        System.assertEquals('Opportunity', report.Origin__c, 'Origin should be Opportunity');
    }

    @isTest
    static void testQueryElysiaReportsByOrigin() {
        Elysia__c r1 = new Elysia__c(Origin__c = 'Lead', Type__c = 'Elysia Report');
        Elysia__c r2 = new Elysia__c(Origin__c = 'Account', Type__c = 'Elysia Report');
        insert new List<Elysia__c>{ r1, r2 };

        List<Elysia__c> leadReports = [SELECT Id FROM Elysia__c WHERE Origin__c = 'Lead'];
        List<Elysia__c> accountReports = [SELECT Id FROM Elysia__c WHERE Origin__c = 'Account'];

        System.assertEquals(1, leadReports.size(), 'Should find one Lead report');
        System.assertEquals(1, accountReports.size(), 'Should find one Account report');
    }
}