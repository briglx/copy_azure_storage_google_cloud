module.exports = async function (context, eventGridEvent) {
  context.log(typeof eventGridEvent);
  context.log(eventGridEvent);
  context.log("Full blob path:", context.bindingData.blobTrigger);
};
