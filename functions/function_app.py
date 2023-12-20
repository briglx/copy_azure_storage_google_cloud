"""Function App code for the Azure Functions Python worker."""
import asyncio
import json
import logging
import os
import subprocess
import uuid
from urllib.parse import urlparse

import aiohttp
import azure.functions as func
import msal
from google.cloud import storage

# from azure.storage.blob.aio import BlobClient

app = func.FunctionApp()


def parse_azure_storage_url(url):
    """Parse an Azure Blob Storage URL into its components.

    Returns a tuple of (storage_account_name, container_name, blob_name).
    Example: https://account_name.blob.core.windows.net/container/folder/myfile.txt
    returns ('account_name', 'container', 'folder/myfile.txt')
    """
    parsed_url = urlparse(url)

    if parsed_url.scheme != "https":
        raise ValueError("URL scheme must be 'https'")

    if parsed_url.netloc.endswith(".blob.core.windows.net"):
        storage_account_name = parsed_url.netloc.split(".")[0]
    else:
        raise ValueError("Invalid Azure Blob Storage URL")

    path_parts = parsed_url.path.strip("/").split("/")

    if len(path_parts) < 2:
        raise ValueError("Invalid path in URL")

    container_name = path_parts[0]
    blob_name = "/".join(path_parts[1:])

    return storage_account_name, container_name, blob_name


async def get_access_token() -> str:
    """Acquire an access token from Azure AD."""
    # Load environment variables
    client_id = os.environ["AZURE_APP_SERVICE_CLIENT_ID"]
    tenant_id = os.environ["AZURE_TENANT_ID"]
    client_credential = os.environ["AZURE_APP_SERVICE_CLIENT_SECRET"]

    authority = f"https://login.microsoftonline.com/{tenant_id}"
    scope = ["https://storage.azure.com/.default"]

    logging.info(
        "Acquire Confidential Client Application access token for client_id %s...",
        client_id,
    )
    client_app = msal.ConfidentialClientApplication(
        client_id, authority=authority, client_credential=client_credential
    )
    result = client_app.acquire_token_for_client(scopes=scope)

    if result and "error" not in result and "access_token" in result:
        access_token = result["access_token"]
        logging.info("access_token %s", access_token)
        return access_token

    logging.error("Failed to acquire access token from Azure AD. %s", result)
    raise ValueError("Failed to acquire access token from Azure AD.")


async def fetch_data(file_url: str) -> str:
    """Read a file from Azure Blob Storage asynchronously.

    Returns the file contents as a string.
    """
    access_token = await get_access_token()
    headers = {
        "Authorization": f"Bearer {access_token}",
        "x-ms-version": "2020-04-08",
    }
    return await fetch_data_by_http(file_url, headers)


# async def fetch_data_by_sdk(container_name: str, blob_name: str) -> str:
#     """Read a file from Azure Blob Storage asynchronously.

#     Returns the file contents as a string.
#     """
#     conn_str = os.environ["BLOB_STORAGE_CONNECTION_STRING"]

#     async with BlobClient.from_connection_string(
#         conn_str=conn_str, container_name=container_name, blob_name=blob_name
#     ) as blob:
#         stream = await blob.download_blob()
#         return await stream.readall()


async def fetch_data_by_http(url, headers):
    """Read a file from Azure Blob Storage asynchronously."""
    async with aiohttp.ClientSession(headers=headers) as session:
        async with session.get(url) as response:
            response_text = await response.text()
            if response.status == 200:
                return response_text

            headers = response.headers
            logging.error(
                "Failed to fetch data from %s. Headers: %s. Message: %s",
                url,
                headers,
                response_text,
            )
            return response_text


def copy_to_gcp_via_shell():
    """Copy data to GCP."""
    shell_script_path = "./script/copy_to_bucket.sh"

    try:
        # Call the shell script using subprocess
        subprocess.run([shell_script_path], check=True)
        print("Shell script executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error executing the shell script: {e}")


# async def get_dwif_credentials(target_principal, dwif_token_file):
#     """Get DWIF credentials."""
#     # Read the DWIF token from the file
#     with open(dwif_token_file, "r") as token_file:
#         dwif_token = token_file.read().strip()

#         from google.oauth2 import service_account

#         target_scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
#         source_credentials = service_account.Credentials.from_service_account_file(
#             dwif_token_file, scopes=target_scopes
#         )

#         logging.info("source_credentials: %s", source_credentials)

#         # Create DWIF credentials
#         target_principal_credentials = (
#             impersonated_credentials.Credentials.from_service_account_file(
#                 dwif_token, target_principal
#             )
#         )

#         return target_principal_credentials


# async def copy_to_bucket(local_file_path):
#     """Upload a local file to a bucket."""
#     GOOGLE_BUCKET_NAME = os.environ.get("GOOGLE_BUCKET_NAME")
#     GOOGLE_CICD_SERVICE_ACCOUNT = os.environ.get("GOOGLE_CICD_SERVICE_ACCOUNT")
#     GOOGLE_CICD_CLIENT_KEY_FILE = os.environ.get("GOOGLE_CICD_CLIENT_KEY_FILE")

#     file_name = os.path.basename(local_file_path)
#     # destination=f"gs://{GOOGLE_BUCKET_NAME}/{file_name}"

#     logging.info(
#         "Uploading %s to %s/%s", local_file_path, GOOGLE_BUCKET_NAME, file_name
#     )
#     logging.info("GOOGLE_CICD_SERVICE_ACCOUNT: %s", GOOGLE_CICD_SERVICE_ACCOUNT)
#     logging.info("GOOGLE_CICD_CLIENT_KEY_FILE: %s", GOOGLE_CICD_CLIENT_KEY_FILE)

#     # Get DWIF credentials
#     credentials = await get_dwif_credentials(
#         GOOGLE_CICD_SERVICE_ACCOUNT, GOOGLE_CICD_CLIENT_KEY_FILE
#     )

#     logging.info("credentials: %s", credentials)

#     # Create a Storage client with DWIF credentials
#     client = storage.Client(credentials=credentials)

#     logging.info("client: %s", client)

#     # Upload the file to the bucket
#     bucket = client.get_bucket(GOOGLE_BUCKET_NAME)
#     blob = bucket.blob(file_name)
#     blob.upload_from_filename(local_file_path)

#     logging.info(
#         "File %s uploaded to %s/%s", local_file_path, GOOGLE_BUCKET_NAME, file_name
#     )


async def copy_to_bucket_via_sdk(source_file_name, destination_blob_name):
    """Copy file to bucket using SDK."""
    bucket_name = os.environ.get("GOOGLE_BUCKET_NAME")
    # GOOGLE_CICD_SERVICE_ACCOUNT = os.environ.get("GOOGLE_CICD_SERVICE_ACCOUNT")
    key_file = os.environ.get("GOOGLE_CICD_CLIENT_KEY_FILE")

    # dest_uri=f"gs://{bucket_name}/{file_name}"

    logging.info(
        "Uploading %s to %s/%s",
        source_file_name,
        bucket_name,
        destination_blob_name,
    )
    # logging.info("GOOGLE_CICD_SERVICE_ACCOUNT: %s", GOOGLE_CICD_SERVICE_ACCOUNT)
    logging.info("GOOGLE_CICD_CLIENT_KEY_FILE: %s", key_file)

    # key_path = 'path/to/your/service-account-key.json'

    # Create a storage client using the service account key
    client = storage.Client.from_service_account_json(key_file)
    bucket = client.get_bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(source_file_name)

    logging.info(
        "File %s uploaded to %s/%s",
        source_file_name,
        bucket_name,
        destination_blob_name,
    )


@app.route(route="test")
async def test_function(req: func.HttpRequest) -> func.HttpResponse:
    """Azure Function triggered by HTTP request."""
    logging.info("HttpTriggerMain triggered")
    temp_file_name = str(uuid.uuid4()) + ".tmp"

    # Read file_url from request query string
    file_url = req.params.get("file_url")

    if not file_url:
        logging.info("file_url not found in query string. Using default test file")
        file_url = "https://ste2isaic2do5jq.blob.core.windows.net/stc-sample/test34.txt"

    logging.info("Get data for test file %s", file_url)
    data = await fetch_data(file_url)
    # data = await fetch_data_by_http(url, headers)

    if data and "Error" not in data:
        logging.info("No error in data")

        logging.info("data: %s", data)
        logging.info("Writing data to local file")

        await asyncio.sleep(5)
        # Write data to local file
        with open(temp_file_name, "w", encoding="utf-8") as f:
            f.write(data)

        dest_file_name = os.path.basename(file_url)
        logging.info("Copy %s to %s", temp_file_name, dest_file_name)
        await copy_to_bucket_via_sdk(temp_file_name, dest_file_name)

        # Clean up temp file
        if os.path.isfile(temp_file_name):
            os.remove(temp_file_name)

        return func.HttpResponse(data, mimetype="text/plain")

    if data and "Error" in data:
        logging.info("Error in data")
        return func.HttpResponse(data, status_code=500, mimetype="text/xml")

    logging.info("Failed to fetch data")
    return func.HttpResponse("Failed to fetch data", status_code=500)


@app.function_name(name="ProcessBlobEvents")
@app.event_grid_trigger(arg_name="event")
async def process_blob_events(event: func.EventGridEvent):
    """Azure Function triggered by Event Grid."""
    json_str = json.dumps(
        {
            "id": event.id,
            "data": event.get_json(),
            "topic": event.topic,
            "subject": event.subject,
            "event_type": event.event_type,
        }
    )

    logging.info("Python EventGrid trigger processed an event: %s", json_str)

    data = event.get_json()
    logging.info("data: %s", data)

    file_url = data["url"]
    logging.info("file_url: %s", file_url)

    data = await fetch_data(file_url)

    logging.info("data: %s", data)
