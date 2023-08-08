module.exports = async function (context, myblob) {
  context.log(typeof myblob);
  context.log(myblob);
};
