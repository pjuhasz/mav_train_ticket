package mavtrainticket

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"github.com/kaitai-io/kaitai_struct_go_runtime/kaitai"
	"io"
	"os"
	"strconv"
	"strings"
)

type Ticket struct {
	Filename string    `json:"filename"`
	Envelope *Envelope `json:"envelope"`
	Payload  *Payload  `json:"payload"`
	Valid    bool      `json:"valid"`
}

func Parse(f io.ReadSeeker) (*Ticket, error) {
	t := &Ticket{}

	s := kaitai.NewStream(f)
	envelope := NewEnvelope()
	err := envelope.Read(s, envelope, envelope)
	if err != nil {
		return nil, fmt.Errorf("Can't parse envelope: %v", err)
	}

	rawBuf := bytes.NewBuffer(envelope.RawPayload)
	gz, err := gzip.NewReader(rawBuf)
	if err != nil {
		return nil, fmt.Errorf("Can't init decompressing payload: %v", err)
	}
	defer gz.Close()

	gzx, err := envelope.Gzip()
	if err != nil {
		return nil, fmt.Errorf("Can't get gzip length from envelope: %v", err)
	}

	expectedLen := int(gzx.LenUncompressed)
	decompressed := make([]byte, expectedLen)
	n, err := io.ReadFull(gz, decompressed)
	if n != expectedLen || err != nil {
		return nil, fmt.Errorf("Can't decompress payload: %v", err)
	}

	decompressedBuf := bytes.NewReader(decompressed)
	s2 := kaitai.NewStream(decompressedBuf)

	payload := NewPayload(envelope.Version)
	err = payload.Read(s2, payload, payload)
	if err != nil {
		return nil, fmt.Errorf("Can't parse ticket: %v", err)
	}

	t.Envelope = envelope
	t.Payload = payload

	if t.Envelope.Version > 4 {
		t.Payload.Header.TicketId = t.Envelope.TicketId
		i, _ := strconv.Atoi(t.Envelope.RicsCode)
		t.Payload.Header.RicsId = uint16(i)
	}

	t.Valid = true

	return t, nil
}

func ParseFile(fn string) (*Ticket, error) {
	f, err := os.Open(fn)
	if err != nil {
		return nil, fmt.Errorf("Can't open file: %v", err)
	}
	defer f.Close()

	t, err := Parse(f)
	if err != nil {
		return nil, err
	}

	t.Filename = fn
	return t, nil
}

func ParseBytes(blob []byte) (*Ticket, error) {
	reader := bytes.NewReader(blob)
	return Parse(reader)
}

func CSVHeader() string {
	var b strings.Builder
	// header
	b.WriteString("filename;")
	b.WriteString("version;")
	b.WriteString("signature_version;")
	b.WriteString("ticket_id;")
	b.WriteString("rics_id;")
	b.WriteString("issued_at;")
	b.WriteString("price;")
	b.WriteString("ticket_medium_tag;")

	// person block
	b.WriteString("name;")
	b.WriteString("birth_date;")
	b.WriteString("id_card_number;")

	// trip block
	b.WriteString("ticket_kind_tag;")
	b.WriteString("departure_station_id;")
	b.WriteString("departure_station_name;")
	b.WriteString("destination_station_id;")
	b.WriteString("destination_station_name;")
	b.WriteString("class;")
	b.WriteString("valid_start_at;")
	b.WriteString("valid_to;")
	b.WriteString("num_passengers;")
	b.WriteString("applied_discounts_tag;")

	// class upgrade block - what if there are > 1? (no such samples so far, though)
	b.WriteString("departure_station_id;")
	b.WriteString("departure_station_name;")
	b.WriteString("destination_station_id;")
	b.WriteString("destination_station_name;")
	b.WriteString("class;")
	b.WriteString("ticket_kind_tag;")
	b.WriteString("valid_start_at;")
	b.WriteString("valid_to;")
	b.WriteString("num_passengers;")
	b.WriteString("applied_discounts_tag;")

	// pass block - what if there are > 1? (no such samples so far, though)
	b.WriteString("ticket_name_tag;")
	b.WriteString("applied_discounts_tag1;")
	b.WriteString("applied_discounts_tag2;")
	b.WriteString("valid_start_at;")
	b.WriteString("valid_to;")
	b.WriteString("num_passengers;")

	// seat reservation block - reserve columns for two
	for i := 0; i < 2; i++ {
		b.WriteString("departure_station_id;")
		b.WriteString("departure_station_name;")
		b.WriteString("destination_station_id;")
		b.WriteString("destination_station_name;")
		b.WriteString("ticket_name_tag;")
		b.WriteString("travel_time;")
		b.WriteString("rics_code;")
		b.WriteString("train_number;")
		b.WriteString("num_passengers;")
		b.WriteString("car_number;")
		b.WriteString("seat_number;")
	}

	b.WriteByte('\n')

	return b.String()
}

func (t Ticket) ToCSV() string {
	if !t.Valid {
		return ""
	}
	var b strings.Builder
	b.WriteString(fmt.Sprintf("%s;%d;%d;%s;%d;%s;%.1f;%08x;",
		t.Filename,
		t.Envelope.Version,
		t.Envelope.SignatureVersion,
		t.Payload.Header.TicketId,
		t.Payload.Header.RicsId,
		t.Payload.Header.IssuedAt.String(),
		t.Payload.Header.Price,
		t.Payload.Header.TicketMedium.Tag,
	))


	if t.Payload.Header.Flags.PersonBlockPresent {
		bl := t.Payload.PersonBlock
		b.WriteString(fmt.Sprintf("%s;%04d-%02d-%02d;%s;",
			bl.Name,
			bl.BirthDate.Year,
			bl.BirthDate.Month,
			bl.BirthDate.Day,
			bl.IdCardNumber,
		))
	} else {
		b.WriteString(";;;")
	}

	if t.Payload.Header.Flags.TripBlockPresent {
		bl := t.Payload.TripBlock
		b.WriteString(fmt.Sprintf("%08x;%d;%s;%d;%s;%s;%s;%s;%d;%08x;",
			bl.TicketKind.Tag,
			bl.DepartureStation.Id,
			bl.DepartureStation.Name,
			bl.DestinationStation.Id,
			bl.DestinationStation.Name,
			bl.Class,
			bl.ValidStartAt.String(),
			bl.ValidInterval.AsTimestamp(bl.ValidStartAt),
			bl.NumPassengers,
			bl.AppliedDiscounts.Tag,
		))
	} else {
		b.WriteString(";;;;;;;;;;")
	}

	// what if there are > 1? (no such samples so far, though)
	if t.Payload.Header.NumClassUpgradeBlocks > 0 {
		bl := t.Payload.ClassUpgradeBlocks[0]
		b.WriteString(fmt.Sprintf("%d;%s;%d;%s;%s;%08x;%s;%s;%d;%08x;", 
			bl.DepartureStation.Id,
			bl.DepartureStation.Name,
			bl.DestinationStation.Id,
			bl.DestinationStation.Name,
			bl.Class,
			bl.TicketKind.Tag,
			bl.ValidStartAt.String(),
			bl.ValidInterval.AsTimestamp(bl.ValidStartAt),
			bl.NumPassengers,
			bl.AppliedDiscounts.Tag,
		))
	} else {
		b.WriteString(";;;;;;;;;;")
	}

	// what if there are > 1? (no such samples so far, though)
	if t.Payload.Header.NumPassBlocks > 0 {
		bl := t.Payload.PassBlocks[0]
		b.WriteString(fmt.Sprintf("%08x;%08x;%08x;%s;%s;%d;", 
			bl.TicketKind.Tag,
			bl.AppliedDiscounts1.Tag,
			bl.AppliedDiscounts2.Tag,
			bl.ValidStartAt.String(),
			bl.ValidInterval.AsTimestamp(bl.ValidStartAt),
			bl.NumPassengers,
		))
	} else {
		b.WriteString(";;;;;;")
	}

	for i := 0; i < len(t.Payload.SeatReservationBlocks); i++ {
		bl := t.Payload.SeatReservationBlocks[i]
		b.WriteString(fmt.Sprintf("%d;%s;%d;%s;%08x;%s;%d;%s;%d;%s;%d;",
			bl.DepartureStation.Id,
			bl.DepartureStation.Name,
			bl.DestinationStation.Id,
			bl.DestinationStation.Name,
			bl.TicketKind.Tag,
			bl.TravelTime.String(),
			bl.RicsCode,
			bl.TrainNumber,
			bl.NumPassengers,
			bl.CarNumber,
			bl.SeatNumber,
		))
	}

	b.WriteByte('\n')

	return b.String()
}
