/**
 * @description Apex class to retrieve all accounts with various filtering and display options
 * @author Assistant
 * @version 1.0
 */
public with sharing class AccountRetriever {
    /**
     * @description Retrieves all accounts with basic fields
     * @return List<Account> List of all accounts
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
                Rating,
                AnnualRevenue,
                NumberOfEmployees,
                BillingCity,
                BillingState,
                Phone,
                Website,
                OwnerId,
                Owner.Name,
                CreatedDate,
                LastModifiedDate
            FROM Account
            ORDER BY Name ASC
            LIMIT 1000
        ];
    }

    /**
     * @description Retrieves all accounts with comprehensive fields
     * @return List<Account> List of all accounts with detailed information
     */
    public static List<Account> getAllAccountsDetailed() {
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
                Rating,
                Site,
                AnnualRevenue,
                NumberOfEmployees,
                Ownership,
                TickerSymbol,
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
                AccountSource,
                OwnerId,
                Owner.Name,
                CreatedDate,
                CreatedBy.Name,
                LastModifiedDate,
                LastModifiedBy.Name,
                SystemModstamp
            FROM Account
            ORDER BY Name ASC
            LIMIT 1000
        ];
    }

    /**
     * @description Retrieves accounts by industry
     * @param industry The industry to filter by
     * @return List<Account> List of accounts in the specified industry
     */
    public static List<Account> getAccountsByIndustry(String industry) {
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
                Rating,
                AnnualRevenue,
                NumberOfEmployees,
                BillingCity,
                BillingState,
                Phone,
                Website,
                OwnerId,
                Owner.Name
            FROM Account
            WHERE Industry = :industry
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Retrieves accounts by type
     * @param accountType The account type to filter by
     * @return List<Account> List of accounts of the specified type
     */
    public static List<Account> getAccountsByType(String accountType) {
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
                Rating,
                AnnualRevenue,
                NumberOfEmployees,
                BillingCity,
                BillingState,
                Phone,
                Website,
                OwnerId,
                Owner.Name
            FROM Account
            WHERE Type = :accountType
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Retrieves accounts with revenue above a specified amount
     * @param minRevenue Minimum annual revenue
     * @return List<Account> List of accounts with revenue above the threshold
     */
    public static List<Account> getAccountsByRevenue(Decimal minRevenue) {
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
                Rating,
                AnnualRevenue,
                NumberOfEmployees,
                BillingCity,
                BillingState,
                Phone,
                Website,
                OwnerId,
                Owner.Name
            FROM Account
            WHERE AnnualRevenue >= :minRevenue
            ORDER BY AnnualRevenue DESC
        ];
    }

    /**
     * @description Retrieves accounts by owner
     * @param ownerId The ID of the account owner
     * @return List<Account> List of accounts owned by the specified user
     */
    public static List<Account> getAccountsByOwner(Id ownerId) {
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
                Rating,
                AnnualRevenue,
                NumberOfEmployees,
                BillingCity,
                BillingState,
                Phone,
                Website,
                OwnerId,
                Owner.Name
            FROM Account
            WHERE OwnerId = :ownerId
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Displays all accounts in a formatted table in debug logs
     */
    public static void displayAccountsTable() {
        List<Account> accounts = getAllAccounts();

        if (accounts.isEmpty()) {
            System.debug('No accounts found in the org.');
            return;
        }

        // Print table header
        System.debug('='.repeat(120));
        System.debug(
            String.format(
                '{0:<18} {1:<25} {2:<12} {3:<10} {4:<15} {5:<8} {6:<12} {7:<10} {8:<15} {9:<10}',
                new List<String>{
                    'ID',
                    'NAME',
                    'ACCOUNT #',
                    'TYPE',
                    'INDUSTRY',
                    'RATING',
                    'REVENUE',
                    'EMPLOYEES',
                    'CITY',
                    'STATE'
                }
            )
        );
        System.debug('='.repeat(120));

        // Print each account as a table row
        for (Account acc : accounts) {
            String revenue = acc.AnnualRevenue != null ? String.valueOf(acc.AnnualRevenue) : 'N/A';
            String employees = acc.NumberOfEmployees != null ? String.valueOf(acc.NumberOfEmployees) : 'N/A';
            String city = String.isNotBlank(acc.BillingCity) ? acc.BillingCity : 'N/A';
            String state = String.isNotBlank(acc.BillingState) ? acc.BillingState : 'N/A';

            System.debug(
                String.format(
                    '{0:<18} {1:<25} {2:<12} {3:<10} {4:<15} {5:<8} {6:<12} {7:<10} {8:<15} {9:<10}',
                    new List<String>{
                        String.valueOf(acc.Id).left(18),
                        acc.Name.left(25),
                        String.isNotBlank(acc.AccountNumber) ? acc.AccountNumber.left(12) : 'N/A',
                        String.isNotBlank(acc.Type) ? acc.Type.left(10) : 'N/A',
                        String.isNotBlank(acc.Industry) ? acc.Industry.left(15) : 'N/A',
                        String.isNotBlank(acc.Rating) ? acc.Rating.left(8) : 'N/A',
                        revenue.left(12),
                        employees.left(10),
                        city.left(15),
                        state.left(10)
                    }
                )
            );
        }

        System.debug('='.repeat(120));
        System.debug('Total Accounts: ' + accounts.size());
        System.debug('='.repeat(120));
    }

    /**
     * @description Returns account statistics
     * @return Map<String, Object> Statistics about accounts
     */
    public static Map<String, Object> getAccountStatistics() {
        List<Account> accounts = getAllAccounts();
        Map<String, Object> stats = new Map<String, Object>();

        stats.put('totalAccounts', accounts.size());

        // Count by industry
        Map<String, Integer> industryCount = new Map<String, Integer>();
        // Count by type
        Map<String, Integer> typeCount = new Map<String, Integer>();
        // Count by rating
        Map<String, Integer> ratingCount = new Map<String, Integer>();

        Decimal totalRevenue = 0;
        Integer totalEmployees = 0;
        Integer accountsWithRevenue = 0;
        Integer accountsWithEmployees = 0;

        for (Account acc : accounts) {
            // Industry count
            String industry = String.isNotBlank(acc.Industry) ? acc.Industry : 'Unknown';
            industryCount.put(industry, industryCount.containsKey(industry) ? industryCount.get(industry) + 1 : 1);

            // Type count
            String type = String.isNotBlank(acc.Type) ? acc.Type : 'Unknown';
            typeCount.put(type, typeCount.containsKey(type) ? typeCount.get(type) + 1 : 1);

            // Rating count
            String rating = String.isNotBlank(acc.Rating) ? acc.Rating : 'Unknown';
            ratingCount.put(rating, ratingCount.containsKey(rating) ? ratingCount.get(rating) + 1 : 1);

            // Revenue and employees
            if (acc.AnnualRevenue != null) {
                totalRevenue += acc.AnnualRevenue;
                accountsWithRevenue++;
            }

            if (acc.NumberOfEmployees != null) {
                totalEmployees += acc.NumberOfEmployees;
                accountsWithEmployees++;
            }
        }

        stats.put('industryBreakdown', industryCount);
        stats.put('typeBreakdown', typeCount);
        stats.put('ratingBreakdown', ratingCount);
        stats.put('totalRevenue', totalRevenue);
        stats.put('totalEmployees', totalEmployees);
        stats.put('accountsWithRevenue', accountsWithRevenue);
        stats.put('accountsWithEmployees', accountsWithEmployees);
        stats.put('averageRevenue', accountsWithRevenue > 0 ? totalRevenue / accountsWithRevenue : 0);
        stats.put('averageEmployees', accountsWithEmployees > 0 ? totalEmployees / accountsWithEmployees : 0);

        return stats;
    }

    /**
     * @description Displays account statistics in debug logs
     */
    public static void displayAccountStatistics() {
        Map<String, Object> stats = getAccountStatistics();

        System.debug('=== ACCOUNT STATISTICS ===');
        System.debug('Total Accounts: ' + stats.get('totalAccounts'));
        System.debug('Total Revenue: $' + stats.get('totalRevenue'));
        System.debug('Total Employees: ' + stats.get('totalEmployees'));
        System.debug('Accounts with Revenue: ' + stats.get('accountsWithRevenue'));
        System.debug('Accounts with Employees: ' + stats.get('accountsWithEmployees'));
        System.debug('Average Revenue: $' + stats.get('averageRevenue'));
        System.debug('Average Employees: ' + stats.get('averageEmployees'));

        System.debug('=== INDUSTRY BREAKDOWN ===');
        Map<String, Integer> industryBreakdown = (Map<String, Integer>) stats.get('industryBreakdown');
        for (String industry : industryBreakdown.keySet()) {
            System.debug(industry + ': ' + industryBreakdown.get(industry));
        }

        System.debug('=== TYPE BREAKDOWN ===');
        Map<String, Integer> typeBreakdown = (Map<String, Integer>) stats.get('typeBreakdown');
        for (String type : typeBreakdown.keySet()) {
            System.debug(type + ': ' + typeBreakdown.get(type));
        }

        System.debug('=== RATING BREAKDOWN ===');
        Map<String, Integer> ratingBreakdown = (Map<String, Integer>) stats.get('ratingBreakdown');
        for (String rating : ratingBreakdown.keySet()) {
            System.debug(rating + ': ' + ratingBreakdown.get(rating));
        }
    }
}