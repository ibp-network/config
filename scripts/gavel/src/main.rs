use clap::{Parser, Subcommand};
use serde_json::{json, Value};
use tokio::main;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use futures_util::{StreamExt, SinkExt};
use rand::{Rng, distributions::Alphanumeric};

#[derive(Parser, Debug)]
#[clap(version = "1.0", about = "Opinionated CLI tool to hammer the data out of blockchain via WebSockets.", long_about = None)]
struct Cli {
    #[clap(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Fetches block data from a blockchain node via WebSocket
    Fetch {
        /// The WebSocket endpoint URL for the blockchain
        endpoint: String,

        /// The block number to fetch, which can be in decimal or hexadecimal format
        #[clap(short, long)]
        block_number: Option<String>,
    },
    /// Generate MMR proof for given block numbers
    Mmr {
        /// The WebSocket endpoint URL for the blockchain
        endpoint: String,

        /// Block numbers for which to generate MMR proofs
        #[clap(required = true)]
        block_numbers: Vec<u64>,
    }
}

#[main]
async fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Fetch { endpoint, block_number } => {
            if let Err(e) = fetch_block(&endpoint, block_number.as_deref()).await {
                eprintln!("Error: {}", e);
            }
        }
        Commands::Mmr { endpoint, block_numbers } => {
            if let Err(e) = get_mmr_proof(&endpoint, block_numbers).await {
                eprintln!("Error: {}", e);
            }
        }
    }
}

async fn decimal_to_hexadecimal(decimal_str: &str) -> Result<String, std::num::ParseIntError> {
    let decimal = decimal_str.parse::<u64>()?;
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

async fn fetch_block(endpoint: &str, block_number: Option<&str>) -> Result<(), Box<dyn std::error::Error>> {
    let formatted_block_number = identify_if_hexadecimal_or_decimal(block_number).await?;

    let (mut socket, _) = connect_async(endpoint).await?;

    let method = if formatted_block_number.is_some() { "chain_getBlockHash" } else { "chain_getHead" };
    let params = json!([formatted_block_number]);

    let block_hash_value = send_and_receive(&mut socket, method, params).await?;

    let block_hash_str = block_hash_value.as_str().ok_or("Expected block hash to be a string")?;

    let block_data = send_and_receive(&mut socket, "chain_getBlock", json!([block_hash_str])).await?;

    println!("{}", serde_json::to_string_pretty(&block_data)?);
    Ok(())
}

async fn get_mmr_proof(endpoint: &str, block_numbers: Vec<u64>) -> Result<(), Box<dyn std::error::Error>> {
    let (mut socket, _) = connect_async(endpoint).await?;

    let params = json!([block_numbers]); // No need to be mutable

    let block_data = send_and_receive(&mut socket, "mmr_generateProof", params).await?;

    println!("{}", serde_json::to_string_pretty(&block_data)?);
    Ok(())
}

async fn send_and_receive(
    socket: &mut tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>,
    method: &str,
    params: serde_json::Value
) -> Result<Value, Box<dyn std::error::Error>> {
    let id_string: String = rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(10)
        .map(char::from)
        .collect();

    let request = json!({
        "jsonrpc": "2.0",
        "id": id_string,
        "method": method,
        "params": params,
    });
    // println!("Sending request: {}", &request);

    socket.send(Message::Text(request.to_string())).await?;

    let response = loop {
        let message = socket.next().await.ok_or("Connection closed before receiving response")??;
        if let Message::Text(text) = message {
            let response: Value = serde_json::from_str(&text)?;
            if response["id"] == id_string {
                break response;
            }
        }
    };

    Ok(response["result"].clone())
}
