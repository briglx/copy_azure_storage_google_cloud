module.exports = async function (context, eventGridEvent) {
  context.log("JavaScript CopyBlob function processed an event:");

  context.log("Blob url:", eventGridEvent.data.url);
  context.log("context.bindingData.data.url:", context.bindingData.data.url);

  context.log("Done!");
};
