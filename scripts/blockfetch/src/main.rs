use clap::Parser;
use serde_json::{json, Value};
use tokio::main;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use futures_util::{StreamExt, SinkExt};

#[derive(Parser, Debug)]
#[clap(version = "1.0", about, long_about = None)]
struct Args {
    /// The WebSocket endpoint URL for the blockchain
    #[clap(short, long)]
    endpoint: String,

    /// The block number to fetch, which can be in decimal or hexadecimal format
    #[clap(short, long)]
    block_number: Option<String>,
}

#[main]
async fn main() {
    let args = Args::parse();
    if let Err(e) = test_endpoint(&args.endpoint, args.block_number.as_deref()).await {
        eprintln!("Error: {}", e);
    }
}

async fn decimal_to_hexadecimal(decimal: &str) -> Result<String, Box<dyn std::error::Error>> {
    let decimal = u64::from_str_radix(decimal, 10)?;
    Ok(format!("{:#x}", decimal))
}

async fn identify_if_hexadecimal_or_decimal(block_number: Option<&str>) -> Result<Option<String>, Box<dyn std::error::Error>> {
    if let Some(number) = block_number {
        if number.starts_with("0x") {
            Ok(Some(number.to_string()))
        } else {
            Ok(Some(decimal_to_hexadecimal(number).await?))
        }
    } else {
        Ok(None)
    }
}

async fn test_endpoint(endpoint: &str, block_number: Option<&str>) -> Result<(), Box<dyn std::error::Error>> {
    let formatted_block_number = identify_if_hexadecimal_or_decimal(block_number).await?;

    let (mut socket, _) = connect_async(endpoint).await?;

    // Determine the method based on whether a block number is provided
    let method = if formatted_block_number.is_some() { "chain_getBlockHash" } else { "chain_getHead" };
    let params = formatted_block_number.as_ref().map(|s| vec![s as &str]).unwrap_or_default();

    let block_hash_value = send_and_receive(&mut socket, method, &params).await?;

    let block_hash_str = block_hash_value.as_str().ok_or("Expected block hash to be a string")?;

    let block_data = send_and_receive(&mut socket, "chain_getBlock", &[block_hash_str]).await?;

    println!("{}", serde_json::to_string_pretty(&block_data)?);
    Ok(())
}

async fn send_and_receive(socket: &mut tokio_tungstenite::WebSocketStream <tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>, method: &str, params: &[&str]) -> Result<Value, Box<dyn std::error::Error>> {
    let request = json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params,
    });

    socket.send(Message::Text(request.to_string())).await?;

    let response = loop {
        let message = socket.next().await.ok_or("Connection closed before receiving response")??;
        if let Message::Text(text) = message {
            let response: Value = serde_json::from_str(&text)?;
            if response["id"] == 1 {
                break response;
            }
        }
    };

    Ok(response["result"].clone())
}
