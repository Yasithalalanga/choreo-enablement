import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/io;
import ballerina/sql;
import ballerinax/salesforce.bulk;

type SalesforceConfig record {|
    string baseUrl;
    string token;
|};

type MysqlConfig record {|
    string hostname;
    string username;
    string password;
    string databaseName;
    int portNumber;
|};

configurable MysqlConfig mysqlConfig = ?;
configurable SalesforceConfig sfConfig = ?;

public function main() returns error? {
    io:println("Triggering the Salesforce Sync...");
    do {
        sql:ParameterizedQuery getContactsQuery = `SELECT * FROM salesforce_db.contacts`;
        stream<record {}, sql:Error?> resultStream = dbClient->query(getContactsQuery);

        // Print the results
        json[] contacts = [];
        check from record {} contact in resultStream
            do {
                contacts.push({
                    description: contact["contact_id"].toString(),
                    FirstName: contact["first_name"].toString(),
                    LastName: contact["last_name"].toString(),
                    Email: contact["email"].toString(),
                    Phone: contact["phone"].toString(),
                    Title: contact["title"].toString()
                });
            };

        // Insert the contacts to Salesforce
        bulk:BulkJob contactInfo = check salesforceEp->createJob("insert", "Contact", "JSON");
        bulk:BatchInfo _ = check salesforceEp->addBatch(contactInfo, contacts);
        bulk:JobInfo batchInfo = check salesforceEp->closeJob(contactInfo);

        io:print("Finished inserting contacts to Salesforce. Job Id: " + batchInfo.id.toString() + "\n");

    } on fail var e {
        io:println(e.message());
    }
}

mysql:Client dbClient = check new (
    host = mysqlConfig.hostname,
    user = mysqlConfig.username,
    password = mysqlConfig.password,
    database = mysqlConfig.databaseName,
    port = mysqlConfig.portNumber
);

bulk:Client salesforceEp = check new (config = {
    baseUrl: sfConfig.baseUrl,
    auth: {
        token: sfConfig.token
    }
});
