package mavtrainticket

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"strconv"
	"github.com/kaitai-io/kaitai_struct_go_runtime/kaitai"
	"compress/gzip"
)

type Ticket struct {
	Fn       string
	Envelope *Envelope
	Payload   *Payload
	Ok       bool
}

func ReadTicket(fn string) (Ticket, error) {
	t := Ticket{
		Fn: fn,
	}

	f, err := os.Open(fn)
	if err != nil {
		return t, fmt.Errorf("Can't open file: %v", err)
	}
	defer f.Close()

	s := kaitai.NewStream(f)
	envelope := NewEnvelope()
	err = envelope.Read(s, envelope, envelope)
	if err != nil {
		return t, fmt.Errorf("Can't parse envelope: %v", err)
	}

	rawBuf := bytes.NewBuffer(envelope.RawPayload)
	gz, err := gzip.NewReader(rawBuf)
	if err != nil {
		return t, fmt.Errorf("Can't init decompressing payload: %v", err)
	}
	defer gz.Close()

	gzx, err := envelope.Gzip()
	if err != nil {
		return t, fmt.Errorf("Can't get gzip length from envelope: %v", err)
	}

	expectedLen := int(gzx.LenUncompressed)
	decompressed := make([]byte, expectedLen)
	n, err := io.ReadFull(gz, decompressed)
	if n != expectedLen || err != nil {
		return t, fmt.Errorf("Can't decompress payload: %v", err)
	}

	decompressedBuf := bytes.NewReader(decompressed)
	s2 := kaitai.NewStream(decompressedBuf)

	payload := NewPayload(envelope.Version)
	err = payload.Read(s2, payload, payload)
	if err != nil {
		return t, fmt.Errorf("Can't parse ticket: %v", err)
	}

	t.Envelope = envelope
	t.Payload = payload

	if t.Envelope.Version > 4 {
		t.Payload.Header.TicketId = t.Envelope.TicketId
		i, _ := strconv.Atoi(t.Envelope.RicsCode)
		t.Payload.Header.RicsId = uint16(i)
	}

	t.Ok = true

	return t, nil
}

func CSVHeader() string {
	var b strings.Builder
	b.WriteString("filename")
	b.WriteByte(';')
	b.WriteString("version")
	b.WriteByte(';')
	b.WriteString("signature_version")
	b.WriteByte(';')
	b.WriteString("ticket_id")
	b.WriteByte(';')
	b.WriteString("rics_id")
	b.WriteByte(';')
	b.WriteString("issued_at")
	b.WriteByte(';')
	b.WriteString("price")
	b.WriteByte(';')
	b.WriteString("ticket_medium_tag")
	b.WriteByte(';')

	if true {
		b.WriteString("name")
		b.WriteByte(';')
		b.WriteString("birth_date")
		b.WriteByte(';')
		b.WriteString("id_card_number")
		b.WriteByte(';')

	}

	if true {
		b.WriteString("ticket_kind_tag")
		b.WriteByte(';')
		// TODO the rest
		b.WriteString("applied_discounts_tag")
		b.WriteByte(';')

	}

	// what if there are > 1? (no such samples so far, though)
	if true {
		b.WriteString("ticket_name_tag")
		b.WriteByte(';')
		b.WriteString("applied_discounts_tag1")
		b.WriteByte(';')
		b.WriteString("applied_discounts_tag2")
		b.WriteByte(';')
		// TODO the rest
	}

	for i := 0; i < 2; i++ {
		b.WriteString(fmt.Sprintf("ticket_name_tag_%d", i+1))
		b.WriteByte(';')
	}

	b.WriteByte('\n')

	return b.String()
}

func (t Ticket) ToCSV() string {
	if !t.Ok {
		return ""
	}
	var b strings.Builder
	b.WriteString(t.Fn)
	b.WriteByte(';')
	b.WriteString(strconv.Itoa(int(t.Envelope.Version)))
	b.WriteByte(';')
	b.WriteString(strconv.Itoa(int(t.Envelope.SignatureVersion)))
	b.WriteByte(';')
	b.WriteString(t.Payload.Header.TicketId)
	b.WriteByte(';')
	b.WriteString(strconv.Itoa(int(t.Payload.Header.RicsId)))
	b.WriteByte(';')
	b.WriteString(t.Payload.Header.IssuedAt.String())
	b.WriteByte(';')
	b.WriteString(fmt.Sprintf("%.1f", t.Payload.Header.Price))
	b.WriteByte(';')
	b.WriteString(fmt.Sprintf("%08x", t.Payload.Header.TicketMedium.Tag))
	b.WriteByte(';')

	if t.Payload.Header.Flags.PersonBlockPresent {
		b.WriteString(t.Payload.PersonBlock.Name)
		b.WriteByte(';')
		b.WriteString(fmt.Sprintf("%04d-%02d-%02d",
			t.Payload.PersonBlock.BirthDate.Year,
			t.Payload.PersonBlock.BirthDate.Month,
			t.Payload.PersonBlock.BirthDate.Day,
		))
		b.WriteByte(';')
		b.WriteString(t.Payload.PersonBlock.IdCardNumber)
		b.WriteByte(';')

	} else {
		b.WriteString(";;;")
	}

	if t.Payload.Header.Flags.TripBlockPresent {
		b.WriteString(fmt.Sprintf("%08x", t.Payload.TripBlock.TicketKind.Tag))
		b.WriteByte(';')
		// TODO the rest
		b.WriteString(fmt.Sprintf("%08x", t.Payload.TripBlock.AppliedDiscounts.Tag))
		b.WriteByte(';')

	} else {
		b.WriteString(";;")
	}

	// what if there are > 1? (no such samples so far, though)
	if t.Payload.Header.NumPassBlocks == 1 {
		b.WriteString(fmt.Sprintf("%08x", t.Payload.PassBlocks[0].TicketKind.Tag))
		b.WriteByte(';')
		b.WriteString(fmt.Sprintf("%08x", t.Payload.PassBlocks[0].AppliedDiscounts1.Tag))
		b.WriteByte(';')
		b.WriteString(fmt.Sprintf("%08x", t.Payload.PassBlocks[0].AppliedDiscounts2.Tag))
		b.WriteByte(';')
		// TODO the rest
	} else {
		b.WriteString(";;;")
	}

	for i := 0; i < len(t.Payload.SeatReservationBlocks); i++ {
		b.WriteString(fmt.Sprintf("%08x", t.Payload.SeatReservationBlocks[i].TicketKind.Tag))
		b.WriteByte(';')
	}

	b.WriteByte('\n')

	return b.String()
}

func (t Ticket) ToJSON() string {
	if !t.Ok {
		return ""
	}
	b, _ := json.Marshal(t.Payload)
	return string(b)
}
