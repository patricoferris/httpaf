module Arg = Caml.Arg

open Httpaf_eio
open Eio.Std

let request_handler (_ : Unix.sockaddr) reqd  = Httpaf_examples.Server.echo_post reqd
let error_handler (_ : Unix.sockaddr) = Httpaf_examples.Server.error_handler

let log_connection_error ex =
  traceln "Uncaught exception handling client: %a" Fmt.exn ex

let main ~network port =
  let listen_address = `Tcp (Unix.(inet_addr_loopback, port)) in
  let handler = Server.create_connection_handler ~request_handler ~error_handler in
  Stdio.printf "Listening on port %i and echoing POST requests.\n" port;
  Stdio.printf "To send a POST request, try one of the following\n\n";
  Stdio.printf "  echo \"Testing echo POST\" | dune exec examples/eio/eio_post.exe\n";
  Stdio.printf "  echo \"Testing echo POST\" | dune exec examples/lwt/lwt_post.exe\n";
  Stdio.printf "  echo \"Testing echo POST\" | curl -XPOST --data @- http://localhost:%d\n\n%!" port;
  Switch.top @@ fun sw ->
  let socket = Eio.Net.listen ~sw ~backlog:5 network listen_address ~reuse_addr:true in
  while true do
    Eio.Net.accept_sub ~sw socket ~on_error:log_connection_error (fun ~sw client_sock client_addr ->
        Fun.protect (fun () -> handler ~sw client_addr client_sock)
          ~finally:(fun () -> Eio.Flow.close client_sock)
      )
  done

let () =
  let port = ref 8080 in
  Arg.parse
    ["-p", Arg.Set_int port, " Listening port number (8080 by default)"]
    ignore
    "Echoes POST requests. Runs forever.";
  Eio_main.run @@ fun env ->
  main !port
    ~network:(Eio.Stdenv.net env)
