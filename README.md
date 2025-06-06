# mailman

A shell-script that authenticate and sends a POST request with a JSON in the body to a configured endpoint.

This can be used in cases where you can not install any software (like postman) to test internal, OnPremises, or restricted/local APIs.

-------

## Instructions

First you must configure your api parameters (inluding auth) in "parametros.sh" file.

After that, create a file with your json data to be sent with the name: "payload_XXX.json", where XXX is the configured endpoint in the "parametros.sh".
If in "parametros.sh" REQUEST_ENDPOINT="my-endpoint" then the json file name must be: "payload_my-endpoint.json"

Then, from a bash terminal, run the command: ./request.sh


## How request.sh works

It with send a POST request to the configured endpoint, using the token from the file: "token.txt"

If it can not find the token in the file, or the request fails with status code 401, it will try to authenticate obtaining a new token and storing it at the file: token.txt

Next, it will try again to send the request using the new token.

"httpcodes.txt" is just a file that the script uses to translate the received HTTP codes from the API.

The API response will be shown in the terminal and stored in the file: "response_XXX.json", where XXX is the configured endpoint in the "parametros.sh".
