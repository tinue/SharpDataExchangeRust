//! Sharp PC-1500 / PC-1600 BASIC tokenizer / de-tokenizer.
//!
//! ROM-style linear scanner (no grammar), reproducing the offline `convert` verb of the
//! Java `SharpDataExchange`. The pure core (`convert`, `scanner`, `detokenize`, `detect`,
//! `header`) has no file I/O and is shared by the CLI (`src/main.rs`) and the C ABI
//! (`ffi`).

pub mod cp437;
pub mod detect;
pub mod detokenize;
pub mod header;
pub mod keywords;
pub mod registry;
pub mod scanner;
pub mod text;

mod abbrev;
pub mod convert;

/// CLI-only filesystem glue (extension rules, output-path derivation). Kept in the
/// library for module wiring, but never called from [`ffi`].
pub mod paths;

pub mod ffi;

pub use convert::{convert, convert_with, ConvertOutcome};
pub use detect::Content;
pub use detokenize::LineEnding;
pub use registry::Device;

/// Crate version string (`CARGO_PKG_VERSION`).
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
