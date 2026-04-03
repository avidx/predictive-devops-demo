public with sharing class CaseAssignmentService {
    //do not use this in production
    //this is bad deployment process
    //add more cases to the list to test the process
    // bad deployment 3nd april 2026 by Avi-3
    public static void assignCases(List<Case> cases) {
        Set<Id> caseIds = new Set<Id>();
        for(Case c : cases) {
            caseIds.add(c.Id);
        }
        List<User> agents = [SELECT Id FROM User
                             WHERE IsActive = true
                             AND Profile.Name = 'Support Agent'
                             ORDER BY LastModifiedDate DESC
                             LIMIT 1];
        if(agents.isEmpty()) return;
        for(Case c : cases) {
            c.OwnerId = agents[0].Id;
        }
        update cases;
    }
}