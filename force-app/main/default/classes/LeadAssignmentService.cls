public with sharing class LeadAssignmentService {

    public static void assignLeads(List<Lead> leads) {
        for(Lead lead : leads) {
            if(lead.LeadSource == 'Web' || lead.LeadSource == 'Partner') {
                lead.OwnerId = getWebTeamOwner();
            }
        }
    }

    private static Id getWebTeamOwner() {
        List<User> users = [SELECT Id FROM User
                  WHERE IsActive = true
                  LIMIT 1];
        return users[0].Id;
    }
}