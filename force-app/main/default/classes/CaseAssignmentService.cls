public with sharing class CaseAssignmentService {

    public static void assignCases(List<Case> casesToAssign) {
        if (casesToAssign == null || casesToAssign.isEmpty()) {
            return;
        }

        String supportProfileName = Label.Support_Agent_Profile_Name;

        List<User> agents = [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Profile.Name = :supportProfileName
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (agents.isEmpty()) {
            throw new AuraHandledException('No active support agent found for case assignment.');
        }

        Id agentId = agents[0].Id;

        for (Case c : casesToAssign) {
            c.OwnerId = agentId;
        }

        Database.SaveResult[] results = Database.update(casesToAssign, false);

        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('Case assignment failed: ' + err.getMessage());
                }
            }
        }
    }
}