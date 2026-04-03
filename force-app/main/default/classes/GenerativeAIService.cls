public with sharing class GenerativeAIService {
    private static final String NAMED_CREDENTIAL = 'OpenAI'; // Replace with your Named Credential name
    private static final String ENDPOINT = '/v1/completions'; // API endpoint for text generation

    public static String generateResponse(String prompt) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        // Set up the request using Named Credentials (recommended approach)
        request.setEndpoint('callout:' + NAMED_CREDENTIAL + ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        // Remove hardcoded API key - Named Credentials handle authentication

        // Construct the JSON payload
        Map<String, Object> payload = new Map<String, Object>{
            'model' => 'text-davinci-003', // Adjust based on the LLM provider
            'prompt' => prompt,
            'max_tokens' => 150,
            'temperature' => 0.7
        };
        request.setBody(JSON.serialize(payload));

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> choices = (List<Object>) responseBody.get('choices');
                if (!choices.isEmpty()) {
                    Map<String, Object> choice = (Map<String, Object>) choices[0];
                    return (String) choice.get('text');
                }
            } else {
                System.debug('Error: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
        return null;
    }
}