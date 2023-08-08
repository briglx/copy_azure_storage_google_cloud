const { app } = require("@azure/functions");

app.http("helloWorld1", {
  methods: ["GET", "POST"],
  handler: async (eventGridEvent, context) => {
    context.log("Node.js EventGrid trigger processed an event:", eventGridEvent);
  },
});

// const blobInput = input.storageBlob({
//   connection: 'DEV_STORAGE',
//   path: 'samples-workitems/{name}',
// });

// app.storageBlob('blobTrigger', {
//   path: 'samples-workitems/{name}',
//   connection: 'DEV_STORAGE',
//   dataType: 'binary',
//   direction: 'in',
//   extraOutputs: [blobInput],
//   handler: (context) => {
//     context.log('Blob trigger function processed');
//     context.log("Full blob path:", context.bindingData.blobTrigger);
//     context.log("Uri:", context.bindingData.uri);
//     context.log("properties:", context.bindingData.properties);
//     context.log("metadata:", context.bindingData.metadata);
//     context.extraOutputs.set(blobInput, context.bindingData);
//   }
// });

// app.storageQueue('readBlob1', {
//   queueName: 'readblobqueue',
//   connection: 'DEV_STORAGE',
//   extraInputs: [blobInput],

//   handler: (queueItem, context) => {
//       context.log('Blob trigger function processed');
//       const blobInputValue = context.extraInputs.get(blobInput);
//       context.log("Uri:", blobInputValue.uri);
//   }
// });

// module.exports = async function (context, eventGridEvent) {
//   context.log('Node.js EventGrid trigger processed an event:', eventGridEvent);

//   const event = JSON.parse(eventGridEvent.data);
//   context.log('Event Type:', event.eventType);

//   if (event.eventType === 'Microsoft.Storage.BlobCreated') {
//     const blobUrl = event.data.url;
//     context.log('New blob added:', blobUrl);
//   }

//   // context.log("Node.js Blob trigger function processed");
//   // context.log("Full blob path:", context.bindingData.blobTrigger);
//   // context.log("Uri:", context.bindingData.uri);
//   // context.log("properties:", context.bindingData.properties);
//   // context.log("metadata:", context.bindingData.metadata);
// };

// module.exports = async function (context) {
//   context.log("Node.js Blob trigger function processed");
//   context.log("Full blob path:", context.bindingData.blobTrigger);
//   context.log("Uri:", context.bindingData.uri);
//   context.log("properties:", context.bindingData.properties);
//   context.log("metadata:", context.bindingData.metadata);
// };
