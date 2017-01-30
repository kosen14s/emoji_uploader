/* Uses the slack button feature to offer a real time bot to multiple teams */
const querystring = require("querystring");
const Botkit = require("botkit");
const os = require("os");

// Heroku上で動かすため、port指定の箇所を !process.env.port から !process.env.PORT に変更
if (!process.env.clientId || !process.env.clientSecret || !process.env.PORT) {
  console.log('Error: Specify clientId clientSecret and port in environment');
  process.exit(1);
}

var controller = Botkit.slackbot({
  // interactive_replies: true, // tells botkit to send button clicks into conversations
  json_file_store: './db_slackbutton_bot/',
}).configureSlackApp(
  {
    clientId: process.env.clientId,
    clientSecret: process.env.clientSecret,
    scopes: ['bot'],
  }
);

controller.setupWebserver(process.env.PORT,function(err,webserver) {
  controller.createWebhookEndpoints(controller.webserver);

  controller.createOauthEndpoints(controller.webserver,function(err,req,res) {
    if (err) {
      res.status(500).send('ERROR: ' + err);
    } else {
      res.send('Success!');
    }
  });
});

// just a simple way to make sure we don't
// connect to the RTM twice for the same team
var _bots = {};
function trackBot(bot) {
  _bots[bot.config.token] = bot;
}

controller.on('create_bot',function(bot,config) {

  if (_bots[bot.config.token]) {
    // already online! do nothing.
  } else {
    bot.startRTM(function(err) {

      if (!err) {
        trackBot(bot);
      }

      bot.startPrivateConversation({user: config.createdBy},function(err,convo) {
        if (err) {
          console.log(err);
        } else {
          convo.say('I am a bot that has just joined your team');
          convo.say('You must now /invite me to a channel so that I can be of use!');
        }
      });
    });
  }
});

// Handle events related to the websocket connection to Slack
controller.on('rtm_open',function(bot) {
  console.log('** The RTM api just connected!');
});

controller.on('rtm_close',function(bot) {
  console.log('** The RTM api just closed');
  // you may want to attempt to re-open
});


// ========================================================================================================================================================================
// 以下 リアクション定義

controller.hears("hi", "direct_message,direct_mention,mention", (bot, message) => {

  bot.reply(message, {
    "text" : "hello"
  });

});


controller.hears("how are you", "direct_message,direct_mention,mention", (bot, message) => {

  bot.reply(message, {
    "text": "Great, you?",
    "attachments": [{
      "fallback": "Couldn't reply.",
      "callback_id": "greeting",
      "attachment_type": 'default',
      "actions": [
        {
          "name": "good",
          "value": "good",
          "text": "Pretty Good",
          "type": "button"
        },{
          "name": "bad",
          "value": "bad",
          "text": "Not so good",
          "type": "button"
        }
      ]
    }]
  });

});


controller.on('interactive_message_callback', function(bot, message) {

  if (message.callback_id == "greeting") {

    const name = message.actions[0].name;
    const value = message.actions[0].value;

    var text = ""

    if (name == "good") {
      text = "That's good."
    } else {
      text = "What's wrong?"
    }

    bot.replyInteractive(message, {
      "text": text
    });
  }

});
