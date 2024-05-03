
use clap::{Parser, Subcommand};
use serde_json::{json, Value};
use tokio::main;
use std::net::Ipv4Addr;
use http::header::{HeaderValue, HOST};
use tokio_tungstenite::{connect_async, MaybeTlsStream};
use tokio_tungstenite::tungstenite::{protocol::Message, client::IntoClientRequest};
use futures_util::{StreamExt, SinkExt};
use rand::{Rng, distributions::Alphanumeric};
use url::Url;
use native_tls::TlsConnector;
use tokio_native_tls::TlsConnector as TokioTlsConnector;
use std::net::{SocketAddr, IpAddr};
use tokio::net::TcpStream;


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
        
        /// Custom resolve the endpoint with IP address
        #[clap(short, long)]
        resolve: Option<Ipv4Addr>,
    },
    /// Generate MMR proof for given block numbers
    Mmr {
        /// The WebSocket endpoint URL for the blockchain
        endpoint: String,

        /// Block numbers for which to generate MMR proofs
        #[clap(required = true)]
        block_numbers: Vec<u64>,

        /// Custom resolve the endpoint with IP address
        #[clap(short, long)]
        resolve: Option<Ipv4Addr>,
    }
}

#[main]
async fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Fetch { endpoint, block_number, resolve } => {
            if let Err(e) = fetch_block(&endpoint, block_number.as_deref(), resolve.as_ref()).await {
                eprintln!("Error: {}", e);
            }
        }
        Commands::Mmr { endpoint, block_numbers, resolve } => {
            if let Err(e) = get_mmr_proof(&endpoint, block_numbers, resolve.as_ref()).await {
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

/// Custom DNS resolution for WebSocket connection
async fn custom_dns_connect(endpoint: &str, dns_override: Option<Ipv4Addr>) -> Result<tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>, Box<dyn std::error::Error>> {
    let url = Url::parse(endpoint)?;
    let addr = if let Some(ip) = dns_override {
        SocketAddr::new(IpAddr::V4(ip), url.port_or_known_default().ok_or("Unknown port for the URL scheme")?)
    } else {
        // Fallback to DNS resolution if no override is provided
        let host = url.host_str().ok_or("Missing host in URL")?;
        format!("{}:{}", host, url.port_or_known_default().unwrap_or(443)).parse::<SocketAddr>()?
    };

    let tcp_stream = TcpStream::connect(addr).await?;
    let tls_connector = TlsConnector::builder()
        .danger_accept_invalid_certs(true) // this required for self-assgined addresses
        .build()?;
    let tokio_tls_connector = TokioTlsConnector::from(tls_connector);
    let tls_stream = tokio_tls_connector.connect(url.host_str().unwrap_or(""), tcp_stream).await?;
    let maybe_tls_stream = MaybeTlsStream::NativeTls(tls_stream);


    let mut request = url.clone().into_client_request()?;
    request.headers_mut().insert(HOST, HeaderValue::from_str(url.host_str().unwrap())?);

    let (socket, _) = tokio_tungstenite::client_async(request, maybe_tls_stream).await?;
    Ok(socket)
}

async fn fetch_block(endpoint: &str, block_number: Option<&str>, ipv4: Option<&Ipv4Addr>) -> Result<(), Box<dyn std::error::Error>> {
    let formatted_block_number = identify_if_hexadecimal_or_decimal(block_number).await?;

    let mut socket = if let Some(ip) = ipv4 {
        let c = custom_dns_connect(endpoint, Some(*ip)).await?;
        c
    } else {
        let (socket, _) = connect_async(endpoint).await?;
        socket
    };

    let method = if formatted_block_number.is_some() { "chain_getBlockHash" } else { "chain_getHead" };
    let params = json!([formatted_block_number]);

    let block_hash_value = send_and_receive(&mut socket, method, params).await?;

    let block_hash_str = block_hash_value.as_str().ok_or("Expected block hash to be a string")?;

    let block_data = send_and_receive(&mut socket, "chain_getBlock", json!([block_hash_str])).await?;

    println!("{}", serde_json::to_string_pretty(&block_data)?);
    Ok(())
}

async fn get_mmr_proof(endpoint: &str, block_numbers: Vec<u64>, ipv4: Option<&Ipv4Addr>) -> Result<(), Box<dyn std::error::Error>> {
    let mut socket = if let Some(ip) = ipv4 {
        let c = custom_dns_connect(endpoint, Some(*ip)).await?;
        c
    } else {
        let (socket, _) = connect_async(endpoint).await?;
        socket
    };

    let params = json!([block_numbers]);

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
