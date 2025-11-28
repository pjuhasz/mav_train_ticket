meta:
  id: mav_train_ticket_envelope
  file-extension: bin
  endian: le
  bit-endian: le
  imports:
   - /archive/gzip
seq:
  - id: version
    type: u1
    valid:
      min: 2
      max: 6
  - id: signature_version
    type: u1
  - id: ticket_id
    size: 18
    type: str
    terminator: 0
    encoding: ascii
    if : version >= 5
  - id: rics_code
    size: 4
    type: str
    terminator: 0
    encoding: ascii
    if : version >= 5
  - id: raw_payload
    size: '_io.size - (version >= 5 ? 24 + 56 : 2 + 256)'
  - id: signature
    size: 'version >= 5 ? 56 : 256'
instances:
  gzip:
    type: gzip
    pos: 'version >= 5 ? 24 : 2'
    size: '_io.size - (version >= 5 ? 24 + 56 : 2 + 256)'
