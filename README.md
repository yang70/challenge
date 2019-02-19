# Mock Rest API Challenge Answer

## Introduction
This document explains the use and implementation I chose to follow for solving the Mock Rest API challenge.  Where possible I tried to make the program as efficient as possible, however the nature of the data and the API meant many API calls needed to be made.  Given the API rate limit of 30 requests per minute, running this program to completion takes close to 50 minutes.

## Usage
After copying the files (main and lib/ ) to your local directory, you must make `main` executable in a Linux or Mac OS terminal by running:

`$ chmod +x main`

Once the API is running and is configured with an API key (see API documentation), run this program from it's directory with the required arguments of the API url and API key.  Example:

`$ ./main http://localhost:9292 myapikey`

When finished the program will write a prettified JSON file to the program directory of the "flattened" organization objects including all of their account and user info as well as a support score.  The `parent` and `children` attributes in the actual Org objects would return the objects themselves, however for serializing into JSON they contain the relevant id's.

## Implementation

### Main
This file is the entry-point for the program and should be made executable.  It takes the API url and API key that were passed as arguments and uses them to instantiate a Data Ingestor instance.

The necessary data is then ingested from the API, "flattened", and then serialized to a JSON file before being written to the local directory.

## Data Ingestor Class
This class is instantiated with an API url and API key and has one public method called `ingest_and_parse`. This method ingests all organization, user and account information and creates the appropriate associations and relationships.  The method returns an array of either "sole" organizations (without any children) or top-level organizations (no parents). From the top-level organization objects you can traverse down through all children organizations.

In order to increase lookup efficiency hash tables are used whenever possible, with keys that eliminate the need for iteration.  Additionally, when data is used it is removed from the hash to increase space efficiency.

## API Operation Class
This class was created to separate logic for making requests and validating/parsing returns from the API.  It has three public methods:

* `read` - Takes a resource path string ("/orgs") and makes a single request to the API.  Also takes an optional params object, if other parameters are needed like page numbers for pagination `{ page: 2 }`.
* `read_all` - This also takes a path string and optional params object, but instead of making one request, if the first response indicates there are additional pages of resources available, additional requests are made until all resources are loaded and returned within an array.
* `read_all_by_id` - This method takes a string path, an array of id integers, and an optional params object.  A request to the API will be made for each id for the resource path given, and all responses will be aggregated into an array and returned.

**Retries and Rate Limit Throttling**

This class implements logic for retries in the case of API errors or hitting a rate request limit.  Up to 5 retries will be made for a request that returns a non 200 response code.  If the response indicates a rate limit was hit, a `throttle` will be set to true which institutes a sleep period before trying the next request attempt.  That sleep period will double for each subsequent rate limit error until either 5 attempts are reached or a successful response is made.  At that point the throttle toggle is switched off for the next attempted request.

The API is limited to 30 requests per minute, so I contemplated instituting a request rate limit to match, however this has the downside of significantly slowing down all requests, even if you're only making several and would never have triggered the rate limit on the API.  In the end I chose a middle ground by instituting a shorter rate limit, currently set to half a second from when the last request was made.  So initial requests and requests made more than a half second from the last will not be slowed, however multiple requests right after each other will be limited to one every half second.  If enough requests are made to trigger the rate limit, slowly increasing wait time in between request retries should ensure enough time to reset the rate limit and continue making requests.

In the event a request exhausts all 5 retries, an API Operation Error exception will be thrown and the program will be stopped with an error message.

## Org Class
This class is the data structure used for representing organizations, the relationships to one another and to their associated users and accounts.

It has the following accessible attributes:

* `id` - Database id of the organization
* `type` - Sole, Parent or Subsidiary
* `parent` - Link to the parent organization, if present
* `children` - Array containing children organizations, if present
* `accounts` - Array of JSON data of all associated accounts
* `users` - Array of JSON data of all associated users

Org public methods:

* `flatten` - This method "flattens" the org object with all "subsidiary" type children orgs in its relationship tree.  It recursively travels to the bottom "leaf" org objects, and consolidates user and account data up the tree until it comes to a "subsidiary" type.  All users and accounts are associated to that "subsidiary" org, and the recursion resets and continues up the tree.  Any non "subsidiary" org objects are removed from the tree after their users and accounts are passed upwards, however all relative hierarchies based on "subsidiary" org objects are maintained.  However the return from this method groups all "subsidiary" org objects and the parent org object into one returned array.
* `support_score` - This method recursively aggregates account revenue for all accounts in the given org's children and returns a score based on the requirement ($0 - $50k > 1, $50k - $100k > 2, etc).
* `accounts_with_subsidiaries` - This method recursively returns all accounts and all associated children's accounts in the org object tree.
* `users_with_subsidiaries` - This method recursively returns all users and all associated children's users in the org object tree.

## API Operation Error Class
Defines a class that inherits from Ruby Standard Error that is raised when the API Operation class exhausts all retry attempts.  It can take an optional error message which will be appended to the standard error message `Error: Invalid Response From API`

## Helpers Module
Small module containing one helper method:

* `org_objects_to_json` - This method takes an array of Org objects and serializes them into a JSON object.  It utilizes the `pretty_generate` method which makes a more human readable JSON file.

# Conclusion
This was a very fun exercise and I love how the API has build in limitations which make it much more realistic.  I look forward to feedback and criticism on what I came up with here!  Thanks!