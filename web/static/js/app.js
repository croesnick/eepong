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
  static init(){
    let socket = new Socket("/socket", {
      logger: ((kind, msg, data) => { console.log(`${kind}: ${msg}`, data) })
    })

    let uuid       = generateUUID()
    socket.connect({user_id: uuid})
    var $status    = $("#status")
    var $messages  = $("#messages")
    var $input     = $("#message-input")
    var $username  = $("#username")
    var $joingame  = $("#join-game")
    var $gamechan  = null

    socket.onOpen( ev => console.log("OPEN", ev) )
    socket.onError( ev => console.log("ERROR", ev) )
    socket.onClose( e => console.log("CLOSE", e))

    var chan = socket.channel("rooms:lobby", {})
    chan.join().receive("ignore", () => console.log("auth error"))
               .receive("ok", () => console.log("join ok"))
               .after(10000, () => console.log("Connection interruption"))
    chan.onError(e => console.log("something went wrong", e))
    chan.onClose(e => console.log("channel closed", e))

    $input.off("keypress").on("keypress", e => {
      if (e.keyCode == 13) {
        chan.push("new:msg", {user: $username.val(), body: $input.val()})
        $input.val("")
      }
    })

    chan.on("new:msg", msg => {
      $messages.append(this.messageTemplate(msg))
      scrollTo(0, document.body.scrollHeight)
    })

    chan.on("user:entered", msg => {
      var username = this.sanitize(msg.user || "anonymous")
      $messages.append(`<br/><i>[${username} entered]</i>`)
    })

    $joingame.on("click", () => {
      chan.push("game:new", null)
    })

    chan.on("game:join", msg => {
      $gamechan = socket.channel("game:" + msg.game, {})
      $gamechan.join().receive("ignore", () => console.log("auth error"))
                      .receive("ok", () => console.log("join ok"))
                      .after(10000, () => console.log("Connection interruption"))
      $gamechan.onError(e => console.log("something went wrong", e))
      $gamechan.onClose(e => console.log("channel closed", e))

      $gamechan.on("new:msg", msg => {
        $messages.append(this.messageTemplate(msg))
        scrollTo(0, document.body.scrollHeight)
      })

      $messages.append(`<p><strong>Joined game ${msg.game}</strong></p>`)
    })

    var elmDiv = document.getElementById('elm-main'),
        elmApp = Elm.embed(Elm.Pong, elmDiv);

    elmApp.ports.movePaddle.subscribe(function(pos) {
      console.log("Key pressed: " + pos)
      if ($gamechan !== null) {
        $gamechan.push("new:msg", {user: "SYSTEM", body: pos})
      }
    })
  }

  static sanitize(html){ return $("<div/>").text(html).html() }

  static messageTemplate(msg){
    let username = this.sanitize(msg.user || "anonymous")
    let body     = this.sanitize(msg.body)

    return(`<p><a href='#'>[${username}]</a>&nbsp; ${body}</p>`)
  }

}

$( () => App.init() )

export default App
