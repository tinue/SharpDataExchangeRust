//! Tokenized payload bytes -> normalized ASCII BASIC listing, ported from Java
//! `BinaryBasicDetokenizer` (which mirrors the ROM `LIST` walk).
//!
//! Output is *normalized*, not the original source: `<lineNo><space>` then, for each
//! keyword, its full name plus exactly one trailing space and no leading space; literal
//! bytes are emitted with no added spacing. Round-trip contract: the line-number
//! sequence survives one pass, and the listing is a fixed point on further round-trips.

use anyhow::{bail, Result};

use crate::cp437;
use crate::registry::{Registry, REM_CODE};

/// De-tokenize `payload` (the bytes *after* any serial header) to one `String` per line.
pub fn detokenize(payload: &[u8], reg: &Registry) -> Result<Vec<String>> {
    let mut lines = Vec::new();
    let mut pos = 0usize;

    while pos + 1 < payload.len() {
        // Program terminator (real-hardware CSAVE files); the encoder never writes it.
        if payload[pos] == 0 && payload[pos + 1] == 0 {
            break;
        }
        if pos + 2 >= payload.len() {
            bail!("malformed payload: truncated line header at offset {pos}");
        }
        let line_no = ((payload[pos] as u16) << 8) | payload[pos + 1] as u16;
        let length = payload[pos + 2] as usize;
        pos += 3;
        if length == 0 {
            bail!("malformed payload: zero length byte for line {line_no} at offset {}", pos - 1);
        }
        let content_end = pos + length - 1; // index of the trailing 0x0D
        if content_end >= payload.len() {
            bail!(
                "malformed payload: line {line_no} at offset {} declares length {length} but only {} bytes remain",
                pos - 3,
                payload.len() - pos
            );
        }

        let mut s = format!("{line_no} ");
        while pos < content_end {
            let b1 = payload[pos];
            if reg.is_two_byte_token_high_byte(b1) {
                let b2 = payload[pos + 1];
                let code = ((b1 as u16) << 8) | b2 as u16;
                match reg.lookup_code(code) {
                    Some(_) if code == REM_CODE => {
                        pos += 2;
                        s.push_str("REM");
                        while pos < content_end {
                            s.push(cp437::to_char(payload[pos]));
                            pos += 1;
                        }
                        break;
                    }
                    Some(kw) => {
                        s.push_str(kw.name);
                        s.push(' ');
                        pos += 2;
                    }
                    None => {
                        // Unknown 2-byte code: emit the lead byte as a literal, advance 1.
                        s.push(cp437::to_char(b1));
                        pos += 1;
                    }
                }
            } else if b1 == 0x22 {
                s.push('"');
                pos += 1;
                while pos < content_end && payload[pos] != 0x22 {
                    s.push(cp437::to_char(payload[pos]));
                    pos += 1;
                }
                if pos < content_end && payload[pos] == 0x22 {
                    s.push('"');
                    pos += 1;
                }
            } else {
                s.push(cp437::to_char(b1));
                pos += 1;
            }
        }

        pos = content_end + 1; // skip the 0x0D
        lines.push(strip_one_trailing_space(s));
    }

    Ok(lines)
}

fn strip_one_trailing_space(mut s: String) -> String {
    if s.ends_with(' ') {
        s.pop();
    }
    s
}

/// Convenience: de-tokenize to a single UTF-8 string, `\n`-joined with a trailing `\n`.
pub fn detokenize_to_text(payload: &[u8], reg: &Registry) -> Result<String> {
    let lines = detokenize(payload, reg)?;
    let mut text = lines.join("\n");
    text.push('\n');
    Ok(text)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::registry;

    #[test]
    fn simple_line() {
        let payload = [0x00u8, 0x0A, 0x0A, 0x22, 0x41, 0x22, 0x3A, 0xF1, 0x87, 0x3A, 0xF1, 0xB3, 0x0D];
        let lines = detokenize(&payload, registry::pc1500()).unwrap();
        assert_eq!(lines, vec!["10 \"A\":CLEAR :WAIT"]);
    }

    #[test]
    fn empty_body_line() {
        let lines = detokenize(&[0x00, 0x0A, 0x01, 0x0D], registry::pc1500()).unwrap();
        assert_eq!(lines, vec!["10"]);
    }

    #[test]
    fn stops_at_program_terminator() {
        let payload = [0x00, 0x0A, 0x01, 0x0D, 0x00, 0x00, 0x99, 0x99];
        let lines = detokenize(&payload, registry::pc1500()).unwrap();
        assert_eq!(lines, vec!["10"]);
    }

    #[test]
    fn bad_length_is_error() {
        assert!(detokenize(&[0x00, 0x0A, 0x40, 0x0D], registry::pc1500()).is_err());
    }
}
