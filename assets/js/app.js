// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

//events
window.addEventListener("game:show_scorecard", (e) =>{
})

// so that the previous interval will be cleared before starting the new interval
// this feels too hacky tbh
let timer;
window.addEventListener( "phx:start-timer", e =>{
  console.log(e.detail)
  let {timer: timer_value, id} = e.detail
  let timer_el = document.getElementById(id)
  timer_el.innerText = timer_value

  //clear existing timer if any?
  clearInterval(timer)
  //first execution happens after delay seconds not instantly
   timer = setInterval(function(){
    //closure instead of parsing every time
    timer_value = timer_value - 1
    let timer_el = document.getElementById(id)
    timer_el.innerText = timer_value

    console.log("timer: ", timer_value)
    if(timer_value == 0) {
      console.log("clearing timer")
      clearInterval(timer)
    }
  }, 1000)
})

window.addEventListener("phx:clear-timer", e => {
  console.log("clearing timer inside event-listener")

  clearInterval(timer)
})

