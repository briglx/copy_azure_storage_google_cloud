import azure.functions as func
import json
import logging
import os
import asyncio
from azure.storage.blob.aio import BlobClient
import sys
from urllib.parse import urlparse

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


async def read_file(container_name: str, blob_name: str) -> str:
    """Read a file from Azure Blob Storage asynchronously.
    Returns the file contents as a string.
    """
    logging.info("blob_name: %s", blob_name)

    try:
        conn_str = os.environ["BLOB_STORAGE_CONNECTION_STRING"]
    except KeyError:
        logging.error("BLOB_STORAGE_CONNECTION_STRING must be set.")
        sys.exit(1)

    # Example of downloading a blob asynchronously
    logging.info("Create blob_client for %s", blob_name)
    async with BlobClient.from_connection_string(
        conn_str=conn_str, container_name=container_name, blob_name=blob_name
    ) as blob:
    
        logging.info("Download blob %s", blob_name)
        stream = await blob.download_blob()
        
        logging.info("Read blob %s", blob_name)
        data = await stream.readall()
        
        logging.info("Blob contents are: %s", data)

    logging.info("Done reading file %s", blob_name)

@app.function_name(name="HttpTrigger1")
@app.route(route="hello")
def test_function(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("HttpTrigger1 function processed a request!")


@app.function_name(name="ProcessBlobEvents")
@app.event_grid_trigger(arg_name="event")
def ProcessBlobEvents(event: func.EventGridEvent):
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

    storage_account, container_name, blob_name = parse_azure_storage_url(file_url)
    logging.info("storage_account: %s", storage_account)
    logging.info("container_name: %s", container_name)
    logging.info("blob_name: %s", blob_name)

    asyncio.run(read_file(container_name, blob_name))
