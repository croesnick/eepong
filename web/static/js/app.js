import {Socket, LongPoller} from "phoenix"

function generateUUID(){
    var d = new Date().getTime();
    if(window.performance && typeof window.performance.now === "function"){
        d += performance.now(); //use high-precision timer if available
    }
    var uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = (d + Math.random()*16)%16 | 0;
        d = Math.floor(d/16);
        return (c=='x' ? r : (r&0x3|0x8)).toString(16);
    });
    return uuid;
}

class App {
  static init() {
    var socket = new Socket("/socket", {
      logger: ((kind, msg, data) => { console.log(`${kind}: ${msg}`, data) })
    })
    
    var elmApp;
    
    var uuid = generateUUID();
    socket.connect({user_id: uuid});

    var username = $("#username");
    username.val(uuid);
    
    var $messages = $("#messages");
    var $joingame = $("#join-game");
    var $gamechan = null;
    
    var lobby = socket.channel("rooms:lobby", {});
    lobby.join();
    
    username.off("keypress").on("keypress", e => {
      if (e.keyCode == 13) {
        lobby.push("client_event:user:data", {user_name: username.val()});
      }
    })

    lobby.on("server_event:status", msg => {
      $messages.append(this.messageTemplate(msg))
      scrollTo(0, document.body.scrollHeight)
    })

    lobby.on("server_event:user:join", msg => {
      var username = this.sanitize(msg.user_name)
      $messages.append(`<br/>[${username} joined]`)
    })
    
    lobby.on("server_event:user:nameChange", msg => {
      var name_now    = this.sanitize(msg.name_now)
      var name_before = this.sanitize(msg.name_before)
      $messages.append(`<br/>[${name_before} is now named ${name_now}]`)
    })

    $joingame.on("click", () => {
      lobby.push("client_event:game:new", null);
    })
    
    lobby.on("server_event:game:join", msg => {
      //TODO Assign the socket only to the $gamechan variable if the receive
      //hook returned an "ok". Otherwise the Elm output port would start too
      //early to push data.
      $gamechan = socket.channel("game:" + msg.game, {});
      $gamechan.join();
    
      var elmInitValues = { inputPort: [false, 0], configPort: msg.player == 1 };
      var elmDiv = document.getElementById('elm-main');
      elmApp = Elm.embed(Elm.Pong, elmDiv, elmInitValues);
    
      elmApp.ports.outputPort.subscribe(function(data) {
        if ($gamechan !== null) {
          var gameEvent = { space: data[0], paddle: data[1] };
          $gamechan.push("client_event:game:state", gameEvent)
        }
      });

      lobby.on("server_event:game:state", msg => {
        var eventData = [ msg["space"], msg["paddle"] ];
        elmApp.ports.inputPort.send(eventData);
      })
    
      $messages.append(`<p><strong>You joined game ${msg.game}</strong></p>`);
      // TODO Enable/load Elm Pong
    })
  }

  static sanitize(html){ return $("<div/>").text(html).html() }

  static messageTemplate(msg){
    var username = this.sanitize(msg.user || "anonymous");
    var body     = this.sanitize(msg.body);

    return(`<p><a href='#'>[${username}]</a>&nbsp; ${body}</p>`)
  }

}

$( () => App.init() )

export default App
