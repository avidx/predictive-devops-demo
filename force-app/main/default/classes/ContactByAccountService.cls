public with sharing class ContactByAccountService {
    /**
     * Retrieves all Contact records for a given Account Id.
     * @param accountId The Id of the Account whose Contacts you want to retrieve.
     * @return List of Contact records related to the Account.
     */
    public static List<Contact> getContactsByAccount(Id accountId) {
        if (accountId == null) {
            throw new IllegalArgumentException('Account Id must not be null');
        }
        // Check CRUD permissions
        if (!Contact.SObjectType.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Contact records');
        }
        return [
            SELECT Id, FirstName, LastName, Email, Phone, Title, AccountId
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY LastName, FirstName
        ];
    }
}