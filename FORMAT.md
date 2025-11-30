# Description of the MÁV train ticket barcode format

## General notes

- PDF 417, Aztec

- international tickets, UIC 918.3

 older format, documented at https://community.kde.org/KDE_PIM/KItinerary/MAV_Barcode


- All strings are zero-padded and left-justified. Presumably they are always
UTF-8 encoded, though in practice this only matters for the passenger name.

- Timestamps are represented as the number of seconds since
  2017-01-01T00:00:00+01:00, as a 32 bit (unsigned?) integer.

## Envelope

- The first byte is the major version number. The current version is 6.

	Here is a table listing the major versions observed so far, the time at which
	they were introduced and the notable changes that came with them. The
	change to version 5 represents the biggest change, where the ticket number
	and issuer code were moved out from the payload to the envelope.

	| Version  | Introduced at | Changes                                 |
	|----------|---------------|-----------------------------------------|
	| 2        | 2016?         |  For testing purposes only? Validity interval was only 2 bytes; timestamp epoch not 2017? |
	| 3        | 2017?         |  For testing purposes only? timestamp epoch to 2017 |
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

### Header block

| Offset  | Size   | Type   | Purpose     | Notes                 |
|---------|--------|--------|-------------|-----------------------|
|         |        |        |             |                       |


### Person block

| Offset  | Size   | Type   | Purpose     | Notes                 |
|---------|--------|--------|-------------|-----------------------|
|         |        |        |             |                       |

### Trip block

| Offset  | Size   | Type   | Purpose     | Notes                 |
|---------|--------|--------|-------------|-----------------------|
|         |        |        |             |                       |

### Class upgrade block

| Offset  | Size   | Type   | Purpose     | Notes                 |
|---------|--------|--------|-------------|-----------------------|
|         |        |        |             |                       |

### Seat reservation block

| Offset  | Size   | Type   | Purpose     | Notes                 |
|---------|--------|--------|-------------|-----------------------|
|         |        |        |             |                       |

### Pass block

| Offset  | Size   | Type   | Purpose     | Notes                 |
|---------|--------|--------|-------------|-----------------------|
|         |        |        |             |                       |
