# Description of the MÁV train ticket barcode format

## General notes

- The format of the actual barcodes can be either PDF 417 or Aztec. The
encoded data is raw binary (so not base64 or hex). The structure and contents
of the encoded data are the same regardless of the appearance of barcode and
the medium of the ticket (e.g. app, web, vending machine).

	There was a news item from 2023 that proudly announced that certain ticket
	types will be printed on credit card sized paper slips, in the name of
	reducing paper waste. (However, due to size limitations they have to print
	a separate ticket for the seat reservations. Oh well.)
	These tickets (and the recently introduced monthly county passes) tend to
	use Aztec codes. The electronic PDFs generated
	by the MÁV website continue to be PDF 417, though.

- The binary format described here is undocumented and proprietary to MÁV,
and it doesn't seem to have any commonality to any common ticket formats.

- This format is used for domestic tickets only. International tickets seem to
follow the UIC 918.3 standard. Also, there is an older format for domestic tickets,
issued until 2020 or so, which used QR codes and a zlib-compressed textual inner
payload. This format is of historical interest only, the tools and documentation
in this repository doesn't cover it. It is documented at the [KItinerary wiki](https://community.kde.org/KDE_PIM/KItinerary/MAV_Barcode).

- The format uses an outer layer or envelope that consists of a fixed header, a
gzip-compressed blob that contains the actual ticket data, and a digital
signature. The ticket data, or payload, is byte-oriented, uses fixed size
blocks of different types, each having a specific, fixed, pre-defined structure.
There are no metadata, field names or padding, no TLV-like strucure, just
the data fields. The various combinations of the different block types
can represent simple, regular train tickets, tickets with surcharges or
penalty fees, and even monthly passes or bus tickets.

- All strings are zero-padded and left-justified. Presumably they are always
UTF-8 encoded, though in practice this only matters for the passenger name.

- Timestamps are represented as the number of seconds since
2017-01-01T00:00:00+01:00, as a 32 bit (unsigned?) integer. (Only exception:
birth date)

- Number encoding is big endian.

- Station ids are encoded as 24 bit integers. In version 4 and before they
were the standard UIC station ids (with prefix 55), but since version 5 they
have switched to an internal numbering scheme that is not publicly documented.
These ids seem to match [Wikidata:P11451](https://www.wikidata.org/wiki/Property:P11451),
though many stations (e.g. Volánbusz stops) are missing from that dataset.

## Envelope

- The first byte is the major version number. The current version is 6.

	Here is a table listing the major versions observed so far, the time at which
	they were introduced and the notable changes that came with them. The
	change to version 5 represents the biggest change, where the ticket number
	and issuer code were moved out from the payload to the envelope.

	| Version  | Introduced at | Changes                                 |
	|----------|---------------|-----------------------------------------|
	| 1        | 2014?         |  For testing purposes only? Base64; Version bytes were in the payload (envelope began with the gzip header); Entirely different payload structure; timestamps used 10000*Y+100*M+D encoding |
	| 2        | 2016?         |  For testing purposes only? Base64; Version bytes moved to envelope; Payload block layout similar to current; Validity interval was only 2 bytes |
	| 3        | 2017?         |  For testing purposes only? timestamp changed to seconds since 2017, as now |
	| 4        | 2017?         |  validity interval to 3 bytes, as now   |
	| 5        | 2021-01-01?   |  ticket number and issuer RICS id moved to envelope, signature shortened |
	| 6        | 2024-08-01?   |  train number length increased to 20    |

	(Not everyone got the memo, though: BKK style county passes with version 5
	were still issued as late as 2025 Nov.)
- The second byte is the version of the signing key. It is likely that 
numbering restarts with each major version, and it is also possible that
each major vendor under the MÁV umbrella gets a dedicated key. (Note that
we don't have the actual keys.)
- Version 5+ only: the ticket number (as printed on the ticket), as a 18 bytes long string.
Train tickets usually begin with 5594.
- Version 5+ only: the RICS code of the issuing company, as a 4 bytes long string.
Observed values: 1155 = MÁV, 0042 = Volánbusz, 0043 = GYSEV, 3663 = MÁV-HÉV
- All versions: the actual ticket contents as a gzip-compressed blob, complete
with the standard `1fb808` magic number, checksum and uncompressed length. The 7
bytes in the gzip header after the magic number are usually filled with zeroes.
- And finally a digital signature. The length is 256 bytes for version 4,
and 56 bytes for version 5 and above. The actual cryptographic algorithm is
not known, though. Nor do we have any of the keys, so currently it is not possible
to verify these signatures.

## Payload

- The payload consists of a header block, which is always present, and a
varying number of blocks, neither of which is mandatory, but at least one
of some kind must be there. There are fields in the header that specify
which blocks are present and how many. The order of the blocks is fixed:
	1. Header
	2. Person block (0 or 1)
	3. Trip block (0 or 1)
	4. Class upgrade block (0 or more, typically at most 1)
	5. Seat reservation block (0 or more, up to 2 observed)
	6. Pass block (0 or more, typically at most 1)

The order of blocks of the same type (e.g. two seat reservation blocks)
tends to follow the order in which they are printed on the ticket.

Some patterns can be observed about the usage of these blocks: for example,
an IC ticket will have a person block with the name and birth date filled in,
a trip block, and at least one seat reservation (and often a second, similar
block that encodes a surcharge). Whereas a monthly ticket will only have
a person block with only the ID card number filled in, and a pass block
with validity information.

The size and structure of these blocks slightly vary depending on the
version number in the envelope.

The payload format apparently uses opaque, non-sequential 32-bit tags
to represent things like ticket kinds, ticket medium, applied discounts,
validity regions etc. These are highly variable, not always stable across
versions, and for the most part, undeciphered. One possibility is that
these are hash keys for the actual strings.

### Header block

The header is 39 bytes long in version 4 and before, and 19 bytes long
in version 5 and above. There is always one per ticket.

The first two fields exist in version 4 only.

| Offset | Size | Type    | Purpose                       | Notes                 |
|--------|------|---------|-------------------------------|-----------------------|
| -/0    | 18   | string  | Ticket id                     | V4 only! As printed on the ticket |
| -/18   | 2    | uint16  | RICS code                     | V4 only!              |
| 0/20   | 4    | time    | Issued at                     |                       |
| 4/24   | 4    | float32 | Price                         | Full price in HUF     |
| 8/28   | 1    | bitmask | Blocks present?               | 0x01: Trip block, 0x80: person block |
| 9/29   | 1    | uint8   | No. of class upgrade blocks   |                       |
| 10/30  | 1    | uint8   | No. of seat reservation blocks|                       |
| 11/31  | 1    | uint8   | No. of pass blocks            |                       |
| 12/32  | 3    | -       | Reserved                      | null                  |
| 15/35  | 4    | uint32  | Ticket medium tag?            | Only a few known values, stable across versions |

Known values for the ticket medium tag:

- `0x236d0520`: electronic_pdf_from_app
- `0x54a5b34d`: thermal_paper_from_emke
- `0x691b8d67`: hologram_paper_from_volanbusz
- `0xa7d59ea6`: paper_from_vending_machine
- `0xc785b60c`: paper_bkk_pass
- `0x338797fe`: electronic_pdf_from_web
- `0xf8b405cd`: thermal_paper_from_ticket_inspector


### Person block

The person block encodes data about the traveller or pass holder. It is
always 64 bytes long. There is at most one per ticket.


| Offset | Size | Type   | Purpose        | Notes                 |
|--------|------|--------|----------------|-----------------------|
| 0      | 45   | string | Name           |                       |
| 45     |  4   | uint32 | Birth date     | encoded as `year * 10000 + month * 100 + day` |
| 49     | 15   | string | ID card number | Only filled for passes |


### Trip block

The trip block encodes basic information about a specific trip that has
a departure and arrival point and validity. It is always 114 bytes long.
There is at most one per ticket.

| Offset | Size | Type      | Purpose                | Notes                 |
|--------|------|-----------|------------------------|-----------------------|
| 0      | 4    | uint32    | Ticket kind tag?       | ???                   |
| 4      | 3    | uint24    | Departure station code |                       |
| 7      | 3    | uint24    | Arrival station code   |                       |
| 10     | 90   | 30*uint24 | Via stations           | null if not set       |
| 100    | 1    | string    | Class                  | "1" or "2"            |
| 101    | 1    | uint8     | No. of trips?          | 0, 1, 2 observed      |
| 102    | 4    | time      | Validity starts at     |                       |
| 106    | 3    | uint24    | Validity interval      | in minutes            |
| 109    | 1    | uint8     | No. of passengers?     | always 1?             |
| 110    | 4    | uint8     | Applied discounts tag? | ???                   |

The identification of the purpose of the first and last fields is uncertain
at best. The observed values vary among samples and versions.

The value of the field tentatively marked as "number of trips" is usually
1 for regular single-trip tickets, 2 for round-trip tickets (which may
have been discontinued as of 2025) and 0 for passes. However, it was observed
that in some pairs of tickets that were purchased at the same time
this field is 0 in one of the tickets and 1 in the other.

### Class upgrade block

This block can represent certain kinds of upgrades or addons to a basic
ticket, e.g. a class upgrade. It is always 23 bytes long. In theory, there
can be more than one, but in practice it is rare and unlikely to occur more
than once per ticket.

| Offset | Size | Type   | Purpose                | Notes                 |
|--------|------|--------|------------------------|-----------------------|
| 0      | 3    | uint24 | Departure station code |                       |
| 3      | 3    | uint24 | Arrival station code   |                       |
| 6      | 1    | string | Class                  | "1" or "2"            |
| 7      | 4    | uint32 | Ticket kind tag?       |                       |
| 11     | 4    | time   | Validity starts at     |                       |
| 15     | 3    | uint24 | Validity interval      | in minutes            |
| 18     | 1    | uint8  | No. of passengers?     | always 1?             |
| 19     | 4    | uint32 | Applied discounts tag? |                       |

Again, the real purpose and meaning of the ticket kind and applied discount
fields is not known.

### Seat reservation block

This block represents seat upgrades, surcharges and similar addons to a
basic ticket that are tied to a specific train or vehicle. It is 57 bytes
long in version 5 and before, and 72 bytes long in version 6. There can be
more than one per ticket, and there often is.

| Offset | Size | Type   | Purpose                | Notes |
|--------|------|--------|------------------------|-------|
| 0      | 3    | uint24 | Departure station code | |
| 3      | 3    | uint24 | Arrival station code   | |
| 6      | 4    | uint32 | Ticket kind tag?       | ??? |
| 10     | 4    | time   | Time of travel         | |
| 14     | 2    | uint16 | RICS code              | operator?, 0x0483 (1155) for MÁV-Start, not necessarily the same as in the header/envelope |
| 16     | 5/20 | string | Train number           |  |
| 21/36  | 1    | uint8  | No. of passengers?     | 0x01 in all samples |
| 22/37  | 3    | string | Coach number           | |
| 25/40  | 2    | uint16 | Seat number            | |
| 27/42  | 2    | uint16 | Seat number            | repeated from previous field? |
| 29/44  | 28   | -      | reserved               | null in all samples |


### Pass block

This block represents information that is not tied to any specific route or vehicle.
Most commonly used in monthly passes, but penalty fees are also represented
by this block. It is always 20 bytes long.
In theory there can be more than one per ticket.

| Offset | Size | Type   | Purpose                | Notes                 |
|--------|------|--------|------------------------|-----------------------|
| 0      | 4    | uint32 | Ticket kind tag?       | ??? Includes validity region? |
| 4      | 4    | uint32 | Applied discounts tag? | ???                   |
| 8      | 4    | uint32 | Applied discounts tag? | ???                   |
| 12     | 4    | time   | Validity starts at     |                       |
| 16     | 3    | uint24 | Validity interval      | in minutes            |
| 19     | 1    | uint8  | No. of passengers?     | always 1?             |

The purpose and meaning of the first 3 fields is completely unknown.
For passes the validity region must be encoded among them somehow, but
it is not known which field is responsible for that.

For penalty fees the validity fields are zero.
