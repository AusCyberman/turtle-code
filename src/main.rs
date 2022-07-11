#[macro_use]
extern crate lazy_static;
use anyhow::Result;
use futures::future;
use futures::{select, sink::SinkExt, stream::FusedStream, stream::StreamExt};
use hyper::{Body, Request, Response};
use hyper_tungstenite::{tungstenite, HyperWebsocket, WebSocketStream};
use log::{info, warn};
use std::io::{stdout, Write};
use std::{convert::Infallible, io::Stdin};
use tokio::io::{stdin, AsyncBufReadExt, AsyncRead, AsyncReadExt, BufReader};
use tokio_stream::wrappers::LinesStream;
use tungstenite::Message;

lazy_static! {
    static ref CLIENT_DATA: Vec<u8> = std::fs::read("./client.lua").unwrap();
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
    let mut lines_from_stdin = LinesStream::new(BufReader::new(stdin()).lines()).fuse();
    print!("lua> ");
    stdout().flush()?;
    loop {
        select! {
            data = lines_from_stdin.select_next_some() => {
                let data = data?;
                websocket.send(Message::Text(data)).await?;
                print!("lua> ");
                stdout().flush()?;
            }
            msg =  websocket.select_next_some() => {
                match msg? {
                    Message::Text(text) => {
                        println!("[CLIENT] {}", text);
                    },
                    Message::Binary(bin) => {
                        info!("Received binary message: {:?}", bin);
                    },
                    Message::Ping(bin) => {
                        info!("Received ping message: {:?}", bin);
                        websocket.send(Message::Pong(bin)).await?;
                    },
                    Message::Pong(bin) => {
                        info!("Received pong message: {:?}", bin);
                    },
                    Message::Close(close) => {
                        info!("Received close message: {:?}", close);
                        return Ok(());
                    },
                    Message::Frame(_) => {
                        info!("Received frame message");
                    }
                }
            }
            complete => {
                println!("closed server");
                break;
            }
        }
    }
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    let addr: std::net::SocketAddr = "[::1]:3000".parse()?;
    println!("Listening on http://{}", addr);
    hyper::Server::bind(&addr)
        .serve(hyper::service::make_service_fn(|_connection| async {
            core::result::Result::Ok::<_, Infallible>(hyper::service::service_fn(handle_request))
        }))
        .await?;
    Ok(())
}
