public with sharing class CaseAssignmentService {

    public static void assignCases(List<Case> casesToAssign) {
        if (casesToAssign == null || casesToAssign.isEmpty()) {
            return;
        }

        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'Support_Case_Queue'
            LIMIT 1
        ];

        if (queues.isEmpty()) {
            throw new AuraHandledException('Support case queue not found.');
        }

        Id queueId = queues[0].Id;

        for (Case c : casesToAssign) {
            c.OwnerId = queueId;
        }

        update casesToAssign;
    }
}