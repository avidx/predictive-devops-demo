public with sharing class StringUtils {
    //utility class - do not use this in production
    //add more utility methods to the class to test the process
    //add more test cases to the class to test the process
    //add more utility methods to the class to test the process
    //low deployment 2nd April 2026
    public static String capitalize(String input) {
        if(input == null || input.length() == 0) return '';
        return input.substring(0, 1).toUpperCase() + input.substring(1).toLowerCase();
    }

    public static Boolean isValidEmail(String email) {
        if(email == null) return false;
        return email.contains('@') && email.contains('.');
    }

    public static String truncate(String input, Integer maxLength) {
        if(input == null) return '';
        if(input.length() <= maxLength) return input;
        return input.left(maxLength);
    }
}
// fix Wed Apr  1 22:04:14 IST 2026
// Wed Apr  1 22:06:11 IST 2026