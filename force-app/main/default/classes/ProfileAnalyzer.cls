/**
 * @description Apex class to analyze profiles and identify those without users
 * @author Assistant
 * @version 1.0
 */
public with sharing class ProfileAnalyzer {
    
    /**
     * @description Analyzes all profiles and identifies those without users
     * @return Map<String, Object> Analysis results with profile statistics
     */
    public static Map<String, Object> analyzeProfilesWithoutUsers() {
        Map<String, Object> results = new Map<String, Object>();
        List<Object> profilesWithoutUsers = new List<Object>();
        Integer totalProfiles = 0;
        Integer profilesWithoutUsersCount = 0;
        
        // Check CRUD permissions
        if (!Profile.SObjectType.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Profile records');
        }
        if (!User.SObjectType.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access User records');
        }
        
        try {
            // Get all profiles
            List<Profile> allProfiles = [
                SELECT Id, Name, Description, UserType, UserLicense.Name
                FROM Profile
                ORDER BY Name
            ];
            
            totalProfiles = allProfiles.size();
            System.debug('Total profiles found: ' + totalProfiles);
            
            // Get user count for each profile
            for (Profile prof : allProfiles) {
                try {
                    // Count users for this profile
                    Integer userCount = [
                        SELECT COUNT()
                        FROM User
                        WHERE ProfileId = :prof.Id AND IsActive = true
                    ];
                    
                    if (userCount == 0) {
                        profilesWithoutUsersCount++;
                        
                        Map<String, Object> profileInfo = new Map<String, Object>{
                            'profileId' => prof.Id,
                            'profileName' => prof.Name,
                            'description' => prof.Description,
                            'userType' => prof.UserType,
                            'userLicense' => prof.UserLicense?.Name,
                            'userCount' => userCount
                        };
                        
                        profilesWithoutUsers.add(profileInfo);
                        
                        System.debug('Profile without users: ' + prof.Name + ' (ID: ' + prof.Id + ')');
                    }
                } catch (Exception e) {
                    System.debug('Error analyzing profile ' + prof.Name + ': ' + e.getMessage());
                }
            }
            
            results.put('totalProfiles', totalProfiles);
            results.put('profilesWithoutUsersCount', profilesWithoutUsersCount);
            results.put('profilesWithoutUsers', profilesWithoutUsers);
            results.put('profilesWithUsersCount', totalProfiles - profilesWithoutUsersCount);
            
        } catch (Exception e) {
            System.debug('Error in profile analysis: ' + e.getMessage());
            throw e;
        }
        
        return results;
    }
    
    /**
     * @description Displays analysis results in a formatted table
     */
    public static void displayProfileAnalysis() {
        System.debug('=== PROFILE ANALYSIS - PROFILES WITHOUT USERS ===');
        
        try {
            Map<String, Object> results = analyzeProfilesWithoutUsers();
            
            Integer totalProfiles = (Integer) results.get('totalProfiles');
            Integer profilesWithoutUsersCount = (Integer) results.get('profilesWithoutUsersCount');
            Integer profilesWithUsersCount = (Integer) results.get('profilesWithUsersCount');
            List<Object> profilesWithoutUsers = (List<Object>) results.get('profilesWithoutUsers');
            
            System.debug('');
            System.debug('=== SUMMARY ===');
            System.debug('Total Profiles: ' + totalProfiles);
            System.debug('Profiles with Users: ' + profilesWithUsersCount);
            System.debug('Profiles without Users: ' + profilesWithoutUsersCount);
            System.debug('Percentage without Users: ' + 
                (totalProfiles > 0 ? ((Decimal) profilesWithoutUsersCount / totalProfiles * 100).setScale(2) : 0) + '%');
            
            if (profilesWithoutUsersCount > 0) {
                System.debug('');
                System.debug('=== PROFILES WITHOUT USERS ===');
                System.debug('='.repeat(120));
                System.debug(
                    String.format(
                        '{0:<35} {1:<20} {2:<15} {3:<20} {4:<10}',
                        new List<String>{
                            'PROFILE NAME',
                            'USER TYPE',
                            'LICENSE',
                            'DESCRIPTION',
                            'USER COUNT'
                        }
                    )
                );
                System.debug('='.repeat(120));
                
                for (Object profileObj : profilesWithoutUsers) {
                    Map<String, Object> profile = (Map<String, Object>) profileObj;
                    String profileName = (String) profile.get('profileName');
                    String userType = (String) profile.get('userType');
                    String userLicense = (String) profile.get('userLicense');
                    String description = (String) profile.get('description');
                    Integer userCount = (Integer) profile.get('userCount');
                    
                    // Truncate long values for display
                    profileName = profileName != null ? profileName.left(35) : 'N/A';
                    userType = userType != null ? userType.left(20) : 'N/A';
                    userLicense = userLicense != null ? userLicense.left(15) : 'N/A';
                    description = description != null ? description.left(20) : 'N/A';
                    
                    System.debug(
                        String.format(
                            '{0:<35} {1:<20} {2:<15} {3:<20} {4:<10}',
                            new List<String>{
                                profileName,
                                userType,
                                userLicense,
                                description,
                                String.valueOf(userCount)
                            }
                        )
                    );
                }
                System.debug('='.repeat(120));
            } else {
                System.debug('');
                System.debug('✅ All profiles have at least one active user assigned!');
            }
            
        } catch (Exception e) {
            System.debug('Error displaying profile analysis: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Generates CSV data for profiles without users
     * @return String CSV formatted data
     */
    public static String generateProfilesWithoutUsersCSV() {
        List<String> csvLines = new List<String>();
        csvLines.add('Profile Name,Profile ID,User Type,User License,Description,User Count');
        
        try {
            Map<String, Object> results = analyzeProfilesWithoutUsers();
            List<Object> profilesWithoutUsers = (List<Object>) results.get('profilesWithoutUsers');
            
            for (Object profileObj : profilesWithoutUsers) {
                Map<String, Object> profile = (Map<String, Object>) profileObj;
                String profileName = (String) profile.get('profileName');
                String profileId = (String) profile.get('profileId');
                String userType = (String) profile.get('userType');
                String userLicense = (String) profile.get('userLicense');
                String description = (String) profile.get('description');
                Integer userCount = (Integer) profile.get('userCount');
                
                // Escape CSV values
                String escapedProfileName = escapeCSVValue(profileName);
                String escapedProfileId = escapeCSVValue(profileId);
                String escapedUserType = escapeCSVValue(userType);
                String escapedUserLicense = escapeCSVValue(userLicense);
                String escapedDescription = escapeCSVValue(description);
                
                csvLines.add(String.format('{0},{1},{2},{3},{4},{5}',
                    new List<String>{
                        escapedProfileName,
                        escapedProfileId,
                        escapedUserType,
                        escapedUserLicense,
                        escapedDescription,
                        String.valueOf(userCount)
                    }
                ));
            }
            
        } catch (Exception e) {
            System.debug('Error generating CSV: ' + e.getMessage());
        }
        
        return String.join(csvLines, '\n');
    }
    
    /**
     * @description Escapes a value for CSV format
     * @param value The value to escape
     * @return String Escaped CSV value
     */
    private static String escapeCSVValue(String value) {
        if (value == null) {
            return '';
        }
        
        // If value contains comma, quote, or newline, wrap in quotes and escape internal quotes
        if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
            return '"' + value.replace('"', '""') + '"';
        }
        
        return value;
    }
}