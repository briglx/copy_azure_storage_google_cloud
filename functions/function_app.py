import azure.functions as func
import json
import logging
import os
import asyncio
from azure.storage.blob import BlobServiceClient
from azure.storage.blob.aio import BlobClient

app = func.FunctionApp()

async def read_file(file_path: str) -> str:

    temp_file_path = f"./temp/{file_path}"

    try:
        conn_str=os.environ["BLOB_STORAGE_CONNECTION_STRING"]

    except KeyError:
        print("BLOB_STORAGE_CONNECTION_STRING must be set.")
        sys.exit(1)

    try:
        container_name=os.environ["BLOB_STORAGE_CONTAINER_NAME"]
    except KeyError:
        print("BLOB_STORAGE_CONTAINER_NAME must be set.")
        sys.exit(1)

    # Example of reading a file from blob storage
    status = None
    blob_service_client = BlobServiceClient.from_connection_string(conn_str)
    async with blob_service_client:
        temp_file = blob_service_client.get_blob_client(container=container_name, blob=temp_file_path)
        await temp_file.start_copy_from_url(file_path)
        for i in range(10):
            props = await temp_file.get_blob_properties()
            status = props.copy.status
            print("Copy status: " + status)
            if status == "success":
                # copy finished
                break
            time.sleep(10)

        if status != "success":
            # if not finished after 100s, cancel the operation
            props = await temp_file.get_blob_properties()
            print(props.copy.status)
            copy_id = props.copy.id
            await temp_file.abort_copy(copy_id)
            props = temp_file.get_blob_properties()
            print(props.copy.status)


    # Example of downloading a blob asynchronously
    blob = BlobClient.from_connection_string(conn_str=conn_str, container_name=container_name, blob_name=file_path)
    with open(temp_file_path, "wb") as my_blob:
        stream = await blob.download_blob()
        data = await stream.readall()
        my_blob.write(data)


    # container_client = blob_service_client.get_container_client(container_name)
    # blob_client = container_client.get_blob_client(blob_url)

    # blob_name = blob_url.split('/')[-1]

    # blob_client = BlobClient.from_connection_string(conn_str=conn_str, container_name=container_name, blob_name=blob_name)

    # temp_file_path = f"./temp/{blob_name}"  
    # with open(temp_file_path, "wb") as temp_file:
    #     stream = await blob.download_blob()
    #     data = await stream.readall()
    #     temp_file.write(data)
    
    # streamdownloader = blob_client.download_blob()

    # # Stream read file to destination
    # file_name = "temp_file.txt"
    # with open(file_name, "wb") as my_blob:
    #     streamdownloader.readinto(my_blob)



@app.function_name(name="HttpTrigger1")
@app.route(route="hello")
def test_function(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("HttpTrigger1 function processed a request!")


@app.function_name(name="eventGridTrigger")
@app.event_grid_trigger(arg_name="event")
def eventGridTest(event: func.EventGridEvent):

    result = json.dumps({
        'id': event.id,
        'data': event.get_json(),
        'topic': event.topic,
        'subject': event.subject,
        'event_type': event.event_type,
    })

    blob_url = result['data']['url']

    logging.info('Python EventGrid trigger processed an event: %s', result)
    logging.info('blob_url: %s', blob_url)
