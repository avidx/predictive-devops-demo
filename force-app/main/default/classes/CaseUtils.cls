public with sharing class CaseUtils {
    
    public static String getCasePriority(Integer age) {
        if(age > 7) return 'High';
        if(age > 3) return 'Medium';
        return 'Low';
    }

    public static String formatCaseSubject(String subject) {
        if(subject == null) return '';
        return subject.trim().left(255);
    }
}