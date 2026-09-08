//! `sde` — SharpDataExchange: offline PC-1500 / PC-1600 BASIC tokenizer / de-tokenizer.
//!
//! `sde convert [options] <infile> [<outfile>]` mirrors the `convert` verb of the Java
//! `SharpDataExchange`. Direction is chosen from file content, not the name.
//! With no `<infile>` and data on stdin, reads stdin and writes stdout.

use std::io::{Read, Write};

use anyhow::{bail, Result};
use clap::{Parser, Subcommand, ValueEnum};

use sharpdx::registry::Device;

#[derive(Parser)]
#[command(name = "sde", version, about = "SharpDataExchange — PC-1500 / PC-1600 BASIC tokenizer / de-tokenizer")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Tokenize / de-tokenize a BASIC file offline (direction detected from content).
    Convert {
        /// Input file. Omit to read from stdin (writes tokenized/de-tokenized bytes to stdout).
        infile: Option<String>,
        /// Output file. If omitted, written next to the input with the target extension.
        outfile: Option<String>,
        /// Keyword table + header flavor when tokenizing (ignored when de-tokenizing).
        #[arg(short, long, value_enum, default_value_t = DeviceArg::Pc1500)]
        device: DeviceArg,
        /// Rejected: direction is always detected from content.
        #[arg(short = 'f', long, hide = true)]
        format: Option<String>,
        /// Verbose logging.
        #[arg(short, long)]
        verbose: bool,
    },
}

#[derive(Copy, Clone, ValueEnum)]
enum DeviceArg {
    Pc1500,
    Pc1500a,
    Pc1600,
    Pc1600emul,
}

impl From<DeviceArg> for Device {
    fn from(d: DeviceArg) -> Self {
        match d {
            DeviceArg::Pc1500 | DeviceArg::Pc1500a => Device::Pc1500,
            DeviceArg::Pc1600 | DeviceArg::Pc1600emul => Device::Pc1600,
        }
    }
}

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Command::Convert { infile, outfile, device, format, verbose } => {
            if format.is_some() {
                bail!("--format is not valid for convert (direction is detected from file content)");
            }
            let _ = verbose;
            match infile {
                Some(path) => {
                    let msg = sharpdx::paths::run_convert(&path, outfile.as_deref(), device.into())?;
                    println!("{msg}");
                }
                None => run_stdio(device.into())?,
            }
            Ok(())
        }
    }
}

fn run_stdio(device: Device) -> Result<()> {
    let mut input = Vec::new();
    std::io::stdin().read_to_end(&mut input)?;
    if input.is_empty() {
        bail!("no input on stdin");
    }
    let outcome = sharpdx::convert(&input, device, None, true)?;
    std::io::stdout().write_all(&outcome.bytes)?;
    Ok(())
}
