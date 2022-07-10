#[macro_use]
extern crate lazy_static;
use futures::{sink::SinkExt, stream::StreamExt, select};
use hyper::{Body, Request, Response};
use hyper_tungstenite::{tungstenite, HyperWebsocket};
use std::convert::Infallible;
use tungstenite::Message;
use anyhow::*;
use log::{info,warn};

lazy_static! {
        static ref CLIENT_DATA : Vec<u8> = std::fs::read("client.lua").unwrap();
}

/// Handle a HTTP or WebSocket request.
async fn handle_request(mut request: Request<Body>) -> Result<Response<Body>> {

    // Check if the request is a websocket upgrade request.
    if hyper_tungstenite::is_upgrade_request(&request) {
        let (response, websocket) = hyper_tungstenite::upgrade(&mut request, None)?;

        // Spawn a task to handle the websocket connection.
        tokio::spawn(async move {
            if let Err(e) = serve_websocket(websocket).await {
                warn!("Error in websocket connection: {}", e);
            }
        });

        // Return the response so the spawned future can continue.
        Ok(response)
    } else {
        // Handle regular HTTP requests here.
        Ok(Response::new(Body::from(CLIENT_DATA.to_vec())))
    }
}

/// Handle a websocket connection.
async fn serve_websocket(websocket: HyperWebsocket) -> Result<()> {
    let mut websocket = websocket.await?;
    loop {
    select! {
        message_m = websocket.next() => {
        match message_m {
            Some(message) =>
        match message? {
            Message::Text(msg) => {
                info!("[CLIENT]: {}", msg);
            },
            Message::Binary(msg) => {
                println!("Received binary message: {:02X?}", msg);
                websocket.send(Message::binary(b"Thank you, come again.".to_vec())).await?;
            },
            Message::Ping(msg) => {
                // No need to send a reply: tungstenite takes care of this for you.
                println!("Received ping message: {:02X?}", msg);
            },
            Message::Pong(msg) => {
                println!("Received pong message: {:02X?}", msg);
            }
            Message::Close(msg) => {
                // No need to send a reply: tungstenite takes care of this for you.
                if let Some(msg) = &msg {
                    println!("Received close message with code {} and message: {}", msg.code, msg.reason);
                } else {
                    println!("Received close message");
                }
            },
            Message::Frame(msg) => {
               unreachable!();
            }
        },
        None => {
            break;
        }
        }
    }


}}
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let addr: std::net::SocketAddr = "[::1]:3000".parse()?;
    println!("Listening on http://{}", addr);
    hyper::Server::bind(&addr).serve(hyper::service::make_service_fn(|_connection| async {
        core::result::Result::Ok::<_, Infallible>(hyper::service::service_fn(handle_request))
    })).await?;
    Ok(())
}