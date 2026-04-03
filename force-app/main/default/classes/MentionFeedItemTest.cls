@isTest
public class MentionFeedItemTest {
    @isTest
    static void testMentionFeedItemTrigger() {
        // Create a test profile
        Profile analyticsProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus Login User Custom' LIMIT 1];
        if (analyticsProfile == null) {
            System.assert(false, 'Customer Community Plus Login User Custom profile not found. Ensure the profile exists.');
        }
        
        // Create a test Account and Contact for the portal user
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
         Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        // Create a test user with the required profile
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = analyticsProfile.Id,
            ContactId = testContact.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Verify the user is retrieved by the SOQL in the trigger
        List<User> usersWithAnalyticsProfile = [SELECT Id, Name FROM User WHERE Profile.Name = 'Customer Community Plus Login User Custom'];
        System.assert(usersWithAnalyticsProfile.size() > 0, 'No users with the Customer Community Plus Login User Customr profile found.');

        // Create a FeedItem with a mention of the test user
        String mentionText = '@' + testUser.Name;
        FeedItem testFeedItem = new FeedItem(
            Body = 'This is a post mentioning ' + mentionText,
            ParentId = UserInfo.getUserId() // Use current user as the parent
        );

        Test.startTest();
            insert testFeedItem;
        Test.stopTest();
    }
}