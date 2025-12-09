# MÁV train ticket barcode data extractor

This repository contains information and tools for decoding the contents
of the barcodes used by MÁV (Hungarian state railway company), Volánbusz
(Hungarian state bus company) and a few related entities.

These barcodes use an undocumented, proprietary binary format for which
no complete description or decoder was available previously. The format
uses an outer layer or envelope that consists of a fixed header, a
gzip-compressed blob that contains the actual ticket data and a digital
signature.

The ticket data uses a byte-oriented, proprietary format with fixed-size
structures in a pre-defined order.

For a more detailed, human-readable description of the format,
see [FORMAT.md](FORMAT.md).

## Features

### Go module

The main attraction of the repo is a ready-to-use Go library that is able
to decode the binary barcode contents and produce a data structure that
contains most of the data incorporated in the ticket.

Minimal example:

```go
package main

import (
	"fmt"
	"os"
	"encoding/json"

	mav "github.com/pjuhasz/mavtrainticket"
)

func main() {
	// parse a ticket from a file
	ticket, err := mav.ParseFile("ticket.bin")
	if err != nil {
		log.Fprintf(os.Stderr, "Can't decode ticket: %v", err)
		return
	}
	// or from a buffer:
	// data = []bytes{ ...ticket data... }
	// ticket, err := mav.ParseBytes(data)

	// replace tag names with human-readable translations 
	ticket.Translate(mav.LangHu)

	// ...and print the contents
	j, _ := json.Marshal(ticket)
	fmt.Print(string(j))

	// or, alternatively, for a more compact representation:
	//fmt.Print(mav.CSVHeader())
	//fmt.Print(ticket.ToCSV())
}
```

See the package documentation for detailed notes on the provided types and
methods. 

Note that this module does not concern itself with reading the actual
physical barcode, you must use an external barcode library or service for that.

### Kaitai struct definitions

Additionally, there are a pair of Kaitai struct definition files for the
envelope and payload formats in the [kaitai](kaitai) directory. These should
serve as the primary documentation for the format, in a way that is
supposedly both human- and machine-readable. It should also be possible to 
use them to generate code that is able to parse ticket data from
for several programming languages. (Note that it is not possible to 
diretly regenerate the go code in this repo from these files - in the end
it had to be edited extensively to be useful.)

### Extra tools

The station codes were extracted from the JSON response of the MÁV train ticket
website at [jegy.mav.hu](jegy.mav.hu). The [tools](tools) directory
contains a Perl script to regenerate the Go source containing the station lookup
map from that.

Previously, the station list was retrieved from the Openstreetmap database via the
[Overpass API](https://overpass-turbo.eu/), but that list was incomplete.
The tools directory also contains the query that retrieves a JSON with this list.

## Limitations

- The signatures are not checked or validated. Even if we knew how to do
that, we don't have the necessary keys (and it's unlikely that we ever will).
- The payload format apparently uses opaque, non-sequential 32-bit tags
to represent things like ticket kinds, ticket medium, applied discounts,
validity regions etc. These are highly variable and for the most part,
undeciphered.
- Neither the go library nor the kaitai definitions handle versions 1 and 2
(but those are of historical interest only, anyway).

## Disclaimer

- The information contained in this repository, source code and documentation
comes from reverse-engineering the author's own tickets and other samples
freely available from the open internet (i.e. comparing samples and staring at
the bytes for long enough). No illegally obtained information was used during
any part of the process.
- There is absolutely no guarantee that the information contained herein
is correct. The author is not responsible for any damages that result from the
use of the code or information in this repository.
- No AI was used for writing any of the code or documentation.
