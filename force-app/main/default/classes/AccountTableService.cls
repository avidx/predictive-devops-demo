public with sharing class AccountTableService {
    /**
     * Retrieves all Account records with key fields for table display.
     */
    public static List<Account> getAllAccounts() {
        // Check CRUD permissions
        if (!Account.SObjectType.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Account records');
        }
        
        return [
            SELECT
                Id,
                Name,
                AccountNumber,
                Type,
                Industry,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                ShippingStreet,
                ShippingCity,
                ShippingState,
                ShippingPostalCode,
                ShippingCountry,
                Phone,
                Fax,
                Website,
                Description,
                AnnualRevenue,
                NumberOfEmployees,
                Rating,
                Site,
                OwnerId,
                CreatedDate,
                LastModifiedDate
            FROM Account
            ORDER BY Name
            LIMIT 1000
        ];
    }
}