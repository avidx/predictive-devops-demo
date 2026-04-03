/**
 * @description Apex class to analyze field data across all objects in the org
 * @author Assistant
 * @version 1.0
 */
public with sharing class FieldDataAnalyzer {
    /**
     * @description Analyzes all objects and their fields to find empty fields
     * @return Map<String, Object> Analysis results with empty field statistics
     */
    public static Map<String, Object> analyzeEmptyFields() {
        Map<String, Object> results = new Map<String, Object>();
        List<Object> emptyFieldDetails = new List<Object>();
        Integer totalEmptyFields = 0;
        Integer totalObjectsAnalyzed = 0;

        // Check CRUD permissions for EntityDefinition
        if (!EntityDefinition.SObjectType.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access EntityDefinition records');
        }
        
        // Get all custom objects
        List<EntityDefinition> customObjects = [
            SELECT QualifiedApiName, Label, IsCustomizable, IsCustomSetting, IsQueryable
            FROM EntityDefinition
            WHERE IsCustomizable = TRUE AND IsCustomSetting = FALSE AND IsQueryable = TRUE
            ORDER BY Label
        ];

        // Add standard objects to analyze
        List<String> standardObjects = new List<String>();
        standardObjects.add('Account');
        standardObjects.add('Contact');
        standardObjects.add('Lead');
        standardObjects.add('Opportunity');
        standardObjects.add('Case');
        standardObjects.add('User');
        standardObjects.add('Task');
        standardObjects.add('Event');
        standardObjects.add('Note');
        standardObjects.add('Attachment');
        standardObjects.add('ContentDocument');

        System.debug('=== STARTING FIELD DATA ANALYSIS ===');
        System.debug(
            'Analyzing ' + customObjects.size() + ' custom objects and ' + standardObjects.size() + ' standard objects'
        );

        // Analyze custom objects
        for (EntityDefinition obj : customObjects) {
            try {
                Map<String, Object> objectAnalysis = analyzeObjectFields(obj.QualifiedApiName, obj.Label);
                if (objectAnalysis != null) {
                    emptyFieldDetails.add(objectAnalysis);
                    totalEmptyFields += (Integer) objectAnalysis.get('emptyFieldCount');
                    totalObjectsAnalyzed++;
                }
            } catch (Exception e) {
                System.debug('Error analyzing object ' + obj.QualifiedApiName + ': ' + e.getMessage());
            }
        }

        // Analyze standard objects
        for (String objName : standardObjects) {
            try {
                Map<String, Object> objectAnalysis = analyzeObjectFields(objName, objName);
                if (objectAnalysis != null) {
                    emptyFieldDetails.add(objectAnalysis);
                    totalEmptyFields += (Integer) objectAnalysis.get('emptyFieldCount');
                    totalObjectsAnalyzed++;
                }
            } catch (Exception e) {
                System.debug('Error analyzing standard object ' + objName + ': ' + e.getMessage());
            }
        }

        results.put('totalObjectsAnalyzed', totalObjectsAnalyzed);
        results.put('totalEmptyFields', totalEmptyFields);
        results.put('objectDetails', emptyFieldDetails);

        return results;
    }

    /**
     * @description Analyzes fields for a specific object
     * @param objectName API name of the object
     * @param objectLabel Display name of the object
     * @return Map<String, Object> Analysis results for the object
     */
    public static Map<String, Object> analyzeObjectFields(String objectName, String objectLabel) {
        Map<String, Object> objectResult = new Map<String, Object>();
        List<String> emptyFields = new List<String>();

        try {
            // Check CRUD permissions for FieldDefinition
            if (!FieldDefinition.SObjectType.getDescribe().isAccessible()) {
                throw new SecurityException('Insufficient permissions to access FieldDefinition records');
            }
            
            // Get field definitions for the object
            List<FieldDefinition> fields = [
                SELECT QualifiedApiName, Label, DataType, IsCalculated, IsNillable
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = :objectName AND IsCalculated = FALSE AND IsNillable = TRUE
                ORDER BY Label
            ];

            if (fields.isEmpty()) {
                return null;
            }

            // Build dynamic SOQL query
            String query = buildFieldQuery(objectName, fields);
            if (String.isBlank(query)) {
                return null;
            }

            // Execute query and analyze results
            List<SObject> records = Database.query(query);

            if (records.isEmpty()) {
                // If no records exist, all fields are considered empty
                for (FieldDefinition field : fields) {
                    emptyFields.add(field.QualifiedApiName);
                }
            } else {
                // Analyze each field for empty values
                for (FieldDefinition field : fields) {
                    if (isFieldEmpty(records, field.QualifiedApiName, field.DataType)) {
                        emptyFields.add(field.QualifiedApiName);
                    }
                }
            }

            objectResult.put('objectName', objectName);
            objectResult.put('objectLabel', objectLabel);
            objectResult.put('totalFields', fields.size());
            objectResult.put('emptyFieldCount', emptyFields.size());
            objectResult.put('emptyFields', emptyFields);
            objectResult.put('totalRecords', records.size());

            // Log results
            System.debug('Object: ' + objectLabel + ' (' + objectName + ')');
            System.debug('  Total Fields: ' + fields.size());
            System.debug('  Empty Fields: ' + emptyFields.size());
            System.debug('  Total Records: ' + records.size());
            if (!emptyFields.isEmpty()) {
                System.debug('  Empty Field Names: ' + String.join(emptyFields, ', '));
            }
        } catch (Exception e) {
            System.debug('Error analyzing object ' + objectName + ': ' + e.getMessage());
            return null;
        }

        return objectResult;
    }

    /**
     * @description Builds a dynamic SOQL query for field analysis
     * @param objectName API name of the object
     * @param fields List of field definitions
     * @return String SOQL query
     */
    public static String buildFieldQuery(String objectName, List<FieldDefinition> fields) {
        if (fields.isEmpty()) {
            return '';
        }

        List<String> fieldNames = new List<String>();
        for (FieldDefinition field : fields) {
            fieldNames.add(field.QualifiedApiName);
        }

        return 'SELECT ' + String.join(fieldNames, ', ') + ' FROM ' + objectName + ' LIMIT 1000';
    }

    /**
     * @description Checks if a field is empty across all records
     * @param records List of SObject records
     * @param fieldName API name of the field
     * @param dataType Data type of the field
     * @return Boolean True if field is empty across all records
     */
    public static Boolean isFieldEmpty(List<SObject> records, String fieldName, String dataType) {
        for (SObject record : records) {
            Object value = record.get(fieldName);
            if (!isValueEmpty(value, dataType)) {
                return false;
            }
        }
        return true;
    }

    /**
     * @description Checks if a field value is empty based on data type
     * @param value Field value
     * @param dataType Data type of the field
     * @return Boolean True if value is empty
     */
    public static Boolean isValueEmpty(Object value, String dataType) {
        if (value == null) {
            return true;
        }

        if (
            dataType.toLowerCase() == 'string' ||
            dataType.toLowerCase() == 'textarea' ||
            dataType.toLowerCase() == 'email' ||
            dataType.toLowerCase() == 'phone' ||
            dataType.toLowerCase() == 'url' ||
            dataType.toLowerCase() == 'encryptedstring'
        ) {
            return String.isBlank((String) value);
        } else if (
            dataType.toLowerCase() == 'number' ||
            dataType.toLowerCase() == 'currency' ||
            dataType.toLowerCase() == 'double' ||
            dataType.toLowerCase() == 'int'
        ) {
            return value == 0 || value == null;
        } else if (dataType.toLowerCase() == 'boolean') {
            return value == false;
        } else if (dataType.toLowerCase() == 'date' || dataType.toLowerCase() == 'datetime') {
            return value == null;
        } else if (dataType.toLowerCase() == 'picklist' || dataType.toLowerCase() == 'multipicklist') {
            return String.isBlank((String) value);
        } else if (dataType.toLowerCase() == 'reference' || dataType.toLowerCase() == 'id') {
            return value == null;
        } else {
            return value == null;
        }
    }

    /**
     * @description Displays analysis results in debug logs
     */
    public static void displayAnalysisResults() {
        Map<String, Object> results = analyzeEmptyFields();

        System.debug('='.repeat(80));
        System.debug('FIELD DATA ANALYSIS RESULTS');
        System.debug('='.repeat(80));
        System.debug('Total Objects Analyzed: ' + results.get('totalObjectsAnalyzed'));
        System.debug('Total Empty Fields Found: ' + results.get('totalEmptyFields'));
        System.debug('='.repeat(80));

        List<Object> objectDetails = (List<Object>) results.get('objectDetails');
        for (Object obj : objectDetails) {
            Map<String, Object> detail = (Map<String, Object>) obj;
            String objectLabel = (String) detail.get('objectLabel');
            Integer emptyCount = (Integer) detail.get('emptyFieldCount');
            Integer totalFields = (Integer) detail.get('totalFields');
            Integer totalRecords = (Integer) detail.get('totalRecords');

            if (emptyCount > 0) {
                System.debug(
                    String.format(
                        '{0:<25} {1:<8} {2:<8} {3:<8}',
                        new List<String>{
                            objectLabel.left(25),
                            String.valueOf(emptyCount),
                            String.valueOf(totalFields),
                            String.valueOf(totalRecords)
                        }
                    )
                );

                List<String> emptyFields = (List<String>) detail.get('emptyFields');
                for (String fieldName : emptyFields) {
                    System.debug('  - ' + fieldName);
                }
            }
        }

        System.debug('='.repeat(80));
    }

    /**
     * @description Returns a summary of empty fields by object
     * @return Map<String, Integer> Object name to empty field count mapping
     */
    public static Map<String, Integer> getEmptyFieldSummary() {
        Map<String, Object> results = analyzeEmptyFields();
        Map<String, Integer> summary = new Map<String, Integer>();

        List<Object> objectDetails = (List<Object>) results.get('objectDetails');
        for (Object obj : objectDetails) {
            Map<String, Object> detail = (Map<String, Object>) obj;
            String objectLabel = (String) detail.get('objectLabel');
            Integer emptyCount = (Integer) detail.get('emptyFieldCount');

            if (emptyCount > 0) {
                summary.put(objectLabel, emptyCount);
            }
        }

        return summary;
    }

    /**
     * @description Generates CSV format of empty fields analysis
     * @return String CSV formatted string with empty fields data
     */
    public static String generateEmptyFieldsCSV() {
        Map<String, Object> results = analyzeEmptyFields();
        List<String> csvLines = new List<String>();

        // Add CSV header
        csvLines.add(
            'Object Name,Object API Name,Field Name,Field API Name,Data Type,Total Records,Empty Percentage,Is Custom Field'
        );

        List<Object> objectDetails = (List<Object>) results.get('objectDetails');
        for (Object obj : objectDetails) {
            Map<String, Object> detail = (Map<String, Object>) obj;
            String objectLabel = (String) detail.get('objectLabel');
            String objectName = (String) detail.get('objectName');
            Integer totalFields = (Integer) detail.get('totalFields');
            Integer emptyFieldCount = (Integer) detail.get('emptyFieldCount');
            Integer totalRecords = (Integer) detail.get('totalRecords');
            List<String> emptyFields = (List<String>) detail.get('emptyFields');

            if (emptyFieldCount > 0) {
                for (String fieldName : emptyFields) {
                    // Determine if it's a custom field
                    Boolean isCustomField = fieldName.endsWith('__c');

                    // Calculate empty percentage
                    Decimal emptyPercentage = totalRecords > 0 ? 100.0 : 0.0;

                    // Escape CSV values
                    String escapedObjectLabel = escapeCSVValue(objectLabel);
                    String escapedObjectName = escapeCSVValue(objectName);
                    String escapedFieldName = escapeCSVValue(fieldName);
                    String escapedFieldApiName = escapeCSVValue(fieldName);

                    // Add CSV row
                    csvLines.add(
                        String.format(
                            '{0},{1},{2},{3},{4},{5},{6},{7}',
                            new List<String>{
                                escapedObjectLabel,
                                escapedObjectName,
                                escapedFieldName,
                                escapedFieldApiName,
                                'Unknown', // Data type not available in current analysis
                                String.valueOf(totalRecords),
                                String.valueOf(emptyPercentage.setScale(2)),
                                isCustomField ? 'Yes' : 'No'
                            }
                        )
                    );
                }
            }
        }

        return String.join(csvLines, '\n');
    }

    /**
     * @description Generates detailed CSV format with field metadata
     * @return String CSV formatted string with detailed field information
     */
    public static String generateDetailedEmptyFieldsCSV() {
        Map<String, Object> results = analyzeEmptyFields();
        List<String> csvLines = new List<String>();

        // Add CSV header
        csvLines.add(
            'Object Name,Object API Name,Field Name,Field API Name,Data Type,Field Label,Is Custom Field,Is Required,Total Records,Empty Records,Empty Percentage,Last Modified Date'
        );

        List<Object> objectDetails = (List<Object>) results.get('objectDetails');
        for (Object obj : objectDetails) {
            Map<String, Object> detail = (Map<String, Object>) obj;
            String objectLabel = (String) detail.get('objectLabel');
            String objectName = (String) detail.get('objectName');
            Integer totalRecords = (Integer) detail.get('totalRecords');
            List<String> emptyFields = (List<String>) detail.get('emptyFields');

            if (!emptyFields.isEmpty()) {
                // Get field metadata for this object
                Map<String, FieldDefinition> fieldMetadata = getFieldMetadata(objectName);

                for (String fieldName : emptyFields) {
                    FieldDefinition fieldDef = fieldMetadata.get(fieldName);

                    // Determine field properties
                    Boolean isCustomField = fieldName.endsWith('__c');
                    String dataType = fieldDef != null ? fieldDef.DataType : 'Unknown';
                    String fieldLabel = fieldDef != null ? fieldDef.Label : fieldName;
                    Boolean isRequired = fieldDef != null ? !fieldDef.IsNillable : false;

                    // Calculate empty percentage
                    Decimal emptyPercentage = totalRecords > 0 ? 100.0 : 0.0;

                    // Escape CSV values
                    String escapedObjectLabel = escapeCSVValue(objectLabel);
                    String escapedObjectName = escapeCSVValue(objectName);
                    String escapedFieldName = escapeCSVValue(fieldName);
                    String escapedFieldLabel = escapeCSVValue(fieldLabel);

                    // Add CSV row
                    csvLines.add(
                        String.format(
                            '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}',
                            new List<String>{
                                escapedObjectLabel,
                                escapedObjectName,
                                escapedFieldName,
                                escapedFieldName,
                                dataType,
                                escapedFieldLabel,
                                isCustomField ? 'Yes' : 'No',
                                isRequired ? 'Yes' : 'No',
                                String.valueOf(totalRecords),
                                String.valueOf(totalRecords), // All records are empty for this field
                                String.valueOf(emptyPercentage.setScale(2)),
                                'N/A' // Last modified date not available in current analysis
                            }
                        )
                    );
                }
            }
        }

        return String.join(csvLines, '\n');
    }

    /**
     * @description Gets field metadata for an object
     * @param objectName API name of the object
     * @return Map<String, FieldDefinition> Field name to field definition mapping
     */
    public static Map<String, FieldDefinition> getFieldMetadata(String objectName) {
        Map<String, FieldDefinition> fieldMetadata = new Map<String, FieldDefinition>();

        try {
            // Check CRUD permissions for FieldDefinition
            if (!FieldDefinition.SObjectType.getDescribe().isAccessible()) {
                throw new SecurityException('Insufficient permissions to access FieldDefinition records');
            }
            
            List<FieldDefinition> fields = [
                SELECT QualifiedApiName, Label, DataType, IsNillable
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = :objectName
                ORDER BY Label
            ];

            for (FieldDefinition field : fields) {
                fieldMetadata.put(field.QualifiedApiName, field);
            }
        } catch (Exception e) {
            System.debug('Error getting field metadata for ' + objectName + ': ' + e.getMessage());
        }

        return fieldMetadata;
    }

    /**
     * @description Escapes a value for CSV format
     * @param value The value to escape
     * @return String Escaped CSV value
     */
    public static String escapeCSVValue(String value) {
        if (value == null) {
            return '';
        }

        // If value contains comma, quote, or newline, wrap in quotes and escape internal quotes
        if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
            return '"' + value.replace('"', '""') + '"';
        }

        return value;
    }
}