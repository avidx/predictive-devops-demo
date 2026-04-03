public class BadApexDemo {
    public static void hitSOQLLimit() {
        for (Integer i = 0; i < 101; i++) {
            List<Account> accs = [SELECT Id FROM Account LIMIT 1];
        }
    }
}