public class QueryChunkingQueuable implements Queueable {
    private Database.Cursor locator;
    private integer position;

    public QueryChunkingQueuable() {
        locator = Database.getCursor
                  ('SELECT Id FROM Contact WHERE LastActivityDate = LAST_N_DAYS:400');
        position = 0;
    }

    public void execute(QueueableContext ctx) {
        List<Contact> scope = locator.fetch(position, 200);
        position += scope.size();
        // do something, like archive or delete the scope list records
        if(position < locator.getNumRecords() ) {
            // process the next chunk
            System.enqueueJob(this);
        }
    }
}