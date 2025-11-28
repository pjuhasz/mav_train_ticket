meta:
  id: mav_train_ticket_payload
  file-extension: bin
  endian: be
  bit-endian: be
params:
  - id: version
    type: u1
seq:
  - id: header
    type: header(version)
  - id: person_block
    type: person_block
    if: header.flags.person_block_present == true
  - id: trip_block
    type: trip_block(version)
    if: header.flags.trip_block_present == true
  - id: seat_reservation_blocks
    type: seat_reservation_block(version)
    repeat: expr
    repeat-expr: header.num_seat_reservation_blocks
  - id: pass_blocks
    type: pass_block(version)
    repeat: expr
    repeat-expr: header.num_pass_blocks
types:
  timestamp:
    doc: |
      Timestamps are represented as the number of seconds since
      2017-01-01T00:00:00+01:00, as 32 bit integer.
    seq:
      - type: u4
        id: seconds_since_2017
    instances:
      seconds_since_1970:
        value: seconds_since_2017 + 1483225200
  birth_date:
    doc: |
      The date of birth is packed into a 32 bit integer with the formula:
        year * 10000 + month * 100 + day
    seq:
      - type: u4
        id: packed
    instances:
      year:
        value: packed / 10000
      month:
        value: (packed - year*10000)/100
      day:
        value: packed - year*10000 - month*100
  station_id:
    params:
      - id: version
        type: u1
    seq:
      - id: id
        type: b24
        
  header_flags:
    seq:
      - id: person_block_present
        type: b1
      - id: reserved_0001
        type: b6
      - id: trip_block_present
        type: b1
  valid_interval:
    params:
      - id: version
        type: u1
    seq:
      - id: minutes
        type:
          switch-on: version
          cases:
            2: u2
            3: u2
            _: b24
  ticket_medium:
    seq:
      - id: tag
        type: u4
        enum: ticket_medium_known_values
    enums:
      ticket_medium_known_values:
        0x236d0520: electronic_pdf_from_app
        0x54a5b34d: thermal_paper_from_emke
        0x691b8d67: hologram_paper_from_volanbusz
        0xa7d59ea6: paper_from_vending_machine
        0xc785b60c: paper_bkk_pass
        0x338797fe: electronic_pdf_from_web
        0xf8b405cd: thermal_paper_from_ticket_inspector
  ticket_kind:
    seq:
      - id: tag
        type: u4
        enum: ticket_kind_known_values
    enums:
      ticket_kind_known_values:
        0xf1694467: potjegy
        0x73b2da6d: helyjegy
  applied_discounts:
    seq:
      - id: tag
        type: u4
  header:
    params:
      - id: version
        type: u1
    seq:
      - id: ticket_id
        size: 18
        type: str
        terminator: 0
        encoding: ascii
        if: version <= 4
      - id: rics_id
        type: u2
        if: version <= 4
      - id: issued_at
        type: timestamp
      - id: price
        type: f4
      - id: flags
        type: header_flags
      - id: reserved_0002
        type: u1
      - id: num_seat_reservation_blocks
        type: u1
      - id: num_pass_blocks
        type: u1
      - id: reserved_0003
        size: 3
      - id: ticket_medium
        type: ticket_medium
  person_block:
    seq:
      - id: name
        type: str
        size: 45
        terminator: 0
        encoding: utf8
      - id: birth_date
        type: birth_date
      - id: id_card_number
        type: str
        size: 15
        terminator: 0
        encoding: ascii
        doc: Often omitted, mostly relevant for passes
  trip_block:
    params:
      - id: version
        type: u1
    seq:
      - id: ticket_kind
        type: ticket_kind
      - id: departure_station
        type: station_id(version)
      - id: destination_station
        type: station_id(version)
      - id: via_stations
        type: station_id(version)
        repeat: expr
        repeat-expr: 30
      - id: class
        size: 1
        type: str
        encoding: ascii
      - id: is_real_ticket
        type: u1
      - id: valid_start_at
        type: timestamp
      - id: valid_interval
        type: valid_interval(version)
      - id: num_passengers
        type: u1
      - id: applied_discounts
        type: applied_discounts
  seat_reservation_block:
    params:
      - id: version
        type: u1
    seq:
      - id: departure_station
        type: station_id(version)
      - id: destination_station
        type: station_id(version)
      - id: ticket_kind
        type: ticket_kind
      - id: travel_time
        type: timestamp
      - id: rics_code
        type: u2
      - id: train_number
        size: 'version >= 6 ? 20 : 5'
        type: str
        terminator: 0
        encoding: ascii
      - id: num_passengers
        type: u1
      - id: car_number
        size: 3
        type: str
        terminator: 0
        encoding: ascii
      - id: seat_number
        type: u2
      - id: seat_number_2
        type: u2
      - size: 28
        id: reserved
  pass_block:
    params:
      - id: version
        type: u1
    seq:
      - id: ticket_kind
        type: ticket_kind
      - id: applied_discounts_1
        type: applied_discounts
      - id: applied_discounts_2
        type: applied_discounts
      - id: travel_time
        type: timestamp
      - id: valid_interval
        type: valid_interval(version)
      - id: num_passengers
        type: u1
      
      
