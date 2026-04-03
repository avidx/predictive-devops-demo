trigger MentionFeedItem on FeedItem(before insert, before update) {
    // Check CRUD permissions
    if (!User.SObjectType.getDescribe().isAccessible()) {
        throw new SecurityException('Insufficient permissions to access User records');
    }
    
    List<User> listUserPlatform = [
        SELECT ID, Name
        FROM User
        WHERE Profile.Name = 'Customer Community Plus Login User Custom'
    ];
    List<String> listNameUserPlatform = new List<String>();

    for (User u : listUserPlatform) {
        listNameUserPlatform.add('@' + u.Name);
        system.debug(listNameUserPlatform);
    }

    for (FeedItem f : Trigger.new) {
        Boolean nameFinded = false;
        for (Integer i = 0; i < listNameUserPlatform.size() && !nameFinded; i++) {
            if (f.Body.contains(listNameUserPlatform.get(i))) {
                nameFinded = true;
                f.addError('You can\'t use mention');
            }
        }
    }
}