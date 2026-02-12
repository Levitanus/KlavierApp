use actix::{
    Actor, ActorContext, AsyncContext, Handler, Message, Recipient, StreamHandler,
};
use log::debug;
use actix_web_actors::ws::{self, WebsocketContext};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WsMessage {
    pub msg_type: String,      // "chat_message", "comment", "typing", "presence", etc.
    pub user_id: Option<i32>,
    pub thread_id: Option<i32>, // For chat
    pub post_id: Option<i32>,   // For comments
    pub data: serde_json::Value,
}

#[derive(Clone)]
pub struct WsServerActor {
    pub connections: Arc<RwLock<HashMap<i32, Recipient<WsNotification>>>>,
    pub user_threads: Arc<RwLock<HashMap<i32, HashSet<i32>>>>, // user_id -> set of thread_ids
    pub thread_watchers: Arc<RwLock<HashMap<i32, HashSet<i32>>>>, // thread_id -> set of user_ids
    pub post_watchers: Arc<RwLock<HashMap<i32, HashSet<i32>>>>, // post_id -> set of user_ids
}

impl Default for WsServerActor {
    fn default() -> Self {
        Self::new()
    }
}

impl WsServerActor {
    pub fn new() -> Self {
        WsServerActor {
            connections: Arc::new(RwLock::new(HashMap::new())),
            user_threads: Arc::new(RwLock::new(HashMap::new())),
            thread_watchers: Arc::new(RwLock::new(HashMap::new())),
            post_watchers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn register_connection(
        &self,
        user_id: i32,
        recipient: Recipient<WsNotification>,
    ) {
        let mut connections = self.connections.write().await;
        connections.insert(user_id, recipient);
        debug!("[ws] user {} connected", user_id);
    }

    pub async fn unregister_connection(&self, user_id: i32) {
        let mut connections = self.connections.write().await;
        connections.remove(&user_id);
        debug!("[ws] user {} disconnected", user_id);

        let mut user_threads = self.user_threads.write().await;
        if let Some(threads) = user_threads.remove(&user_id) {
            let mut thread_watchers = self.thread_watchers.write().await;
            for thread_id in threads {
                if let Some(watchers) = thread_watchers.get_mut(&thread_id) {
                    watchers.remove(&user_id);
                }
            }
        }
    }

    pub async fn subscribe_to_thread(&self, user_id: i32, thread_id: i32) {
        // Add user to thread watchers
        let mut thread_watchers = self.thread_watchers.write().await;
        thread_watchers
            .entry(thread_id)
            .or_insert_with(HashSet::new)
            .insert(user_id);

        // Track user's threads
        let mut user_threads = self.user_threads.write().await;
        user_threads
            .entry(user_id)
            .or_insert_with(HashSet::new)
            .insert(thread_id);
        debug!("[ws] user {} subscribed to thread {}", user_id, thread_id);
    }

    pub async fn subscribe_to_post(&self, user_id: i32, post_id: i32) {
        let mut post_watchers = self.post_watchers.write().await;
        post_watchers
            .entry(post_id)
            .or_insert_with(HashSet::new)
            .insert(user_id);
        debug!("[ws] user {} subscribed to post {}", user_id, post_id);
    }

    pub async fn broadcast_to_thread(&self, thread_id: i32, message: WsMessage) {
        let thread_watchers = self.thread_watchers.read().await;
        if let Some(watchers) = thread_watchers.get(&thread_id) {
            debug!(
                "[ws] broadcast {} to thread {} ({} watchers)",
                message.msg_type,
                thread_id,
                watchers.len()
            );
            let connections = self.connections.read().await;
            for user_id in watchers {
                if let Some(recipient) = connections.get(user_id) {
                    let _ = recipient.do_send(WsNotification(message.clone()));
                }
            }
        }
    }

    pub async fn broadcast_to_post(&self, post_id: i32, message: WsMessage) {
        let post_watchers = self.post_watchers.read().await;
        if let Some(watchers) = post_watchers.get(&post_id) {
            let connections = self.connections.read().await;
            for user_id in watchers {
                if let Some(recipient) = connections.get(user_id) {
                    let _ = recipient.do_send(WsNotification(message.clone()));
                }
            }
        }
    }

    pub async fn broadcast_typing(&self, thread_id: i32, user_id: i32, is_typing: bool) {
        let message = WsMessage {
            msg_type: "typing".to_string(),
            user_id: Some(user_id),
            thread_id: Some(thread_id),
            post_id: None,
            data: serde_json::json!({ "is_typing": is_typing }),
        };
        self.broadcast_to_thread(thread_id, message).await;
    }

    pub async fn send_presence(&self, user_id: i32, is_online: bool) {
        let message = WsMessage {
            msg_type: "presence".to_string(),
            user_id: Some(user_id),
            thread_id: None,
            post_id: None,
            data: serde_json::json!({ "is_online": is_online }),
        };

        // Send to all connections this user has subscribed threads
        let user_threads = self.user_threads.read().await;
        if let Some(threads) = user_threads.get(&user_id) {
            for thread_id in threads {
                self.broadcast_to_thread(*thread_id, message.clone()).await;
            }
        }
    }
}

#[derive(Message)]
#[rtype(result = "()")]
pub struct WsNotification(pub WsMessage);

pub struct WsSession {
    pub user_id: i32,
    pub server: WsServerActor,
}

impl Actor for WsSession {
    type Context = WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        let server = self.server.clone();
        let user_id = self.user_id;
        let recipient = ctx.address().recipient();

        // Register connection asynchronously
        actix::spawn(async move {
            server.register_connection(user_id, recipient).await;
            server.send_presence(user_id, true).await;
        });
    }

    fn stopped(&mut self, _ctx: &mut Self::Context) {
        let server = self.server.clone();
        let user_id = self.user_id;

        actix::spawn(async move {
            server.send_presence(user_id, false).await;
            server.unregister_connection(user_id).await;
        });
    }
}

impl Handler<WsNotification> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: WsNotification, ctx: &mut Self::Context) {
        let json = serde_json::to_string(&msg.0).unwrap_or_default();
        ctx.text(json);
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for WsSession {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(ws::Message::Ping(msg)) => {
                ctx.pong(&msg);
            }
            Ok(ws::Message::Pong(_)) => {
                // Pong received
            }
            Ok(ws::Message::Text(text)) => {
                debug!("[ws] received text: {}", text);
                let server = self.server.clone();
                let user_id = self.user_id;

                // Parse incoming message
                match serde_json::from_str::<WsMessage>(&text) {
                    Ok(ws_msg) => {
                        debug!("[ws] parsed msg_type={}", ws_msg.msg_type);
                        actix::spawn(async move {
                            match ws_msg.msg_type.as_str() {
                                "subscribe_thread" => {
                                    if let Some(thread_id) = ws_msg.thread_id {
                                        server.subscribe_to_thread(user_id, thread_id).await;
                                    } else {
                                        debug!("[ws] subscribe_thread missing thread_id");
                                    }
                                }
                                "subscribe_post" => {
                                    if let Some(post_id) = ws_msg.post_id {
                                        server.subscribe_to_post(user_id, post_id).await;
                                    } else {
                                        debug!("[ws] subscribe_post missing post_id");
                                    }
                                }
                                "typing" => {
                                    if let Some(thread_id) = ws_msg.thread_id {
                                        let is_typing = ws_msg.data["is_typing"]
                                            .as_bool()
                                            .unwrap_or(false);
                                        server
                                            .broadcast_typing(thread_id, user_id, is_typing)
                                            .await;
                                    } else {
                                        debug!("[ws] typing missing thread_id");
                                    }
                                }
                                _ => {
                                    debug!("[ws] unhandled msg_type={}", ws_msg.msg_type);
                                }
                            }
                        });
                    }
                    Err(err) => {
                        debug!("[ws] failed to parse ws message: {}", err);
                    }
                }
            }
            Ok(ws::Message::Binary(_bin)) => {
                debug!("Unexpected binary message");
            }
            Ok(ws::Message::Close(reason)) => {
                ctx.close(reason);
            }
            Ok(ws::Message::Continuation(_)) => {
                // Skip continuation messages
            }
            Ok(ws::Message::Nop) => {
                // No operation
            }
            Err(e) => {
                debug!("WebSocket error: {:?}", e);
                ctx.stop();
            }
        }
    }
}
