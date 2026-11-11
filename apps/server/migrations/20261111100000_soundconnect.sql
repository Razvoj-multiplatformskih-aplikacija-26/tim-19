-- migrate:up

-- Nalozi i profili klijenata. Klijent i pružalac imaju nalog sa istim identifikatorom kao profil.
-- Lozinka je samo Argon2id heš; korisnik bez prijave (login IS NULL) postoji samo kao ime u zahtevima.
CREATE TABLE users (
  id text PRIMARY KEY,
  name text NOT NULL CHECK (char_length(name) > 0),
  role text NOT NULL CHECK (role IN ('client', 'provider', 'moderator')),
  login text UNIQUE,
  password_hash text,
  CONSTRAINT users_login_has_password CHECK ((login IS NULL) = (password_hash IS NULL))
);

-- Profili pružalaca. Cena je ceo broj evra.
CREATE TABLE providers (
  id text PRIMARY KEY,
  name text NOT NULL CHECK (char_length(name) > 0),
  verified boolean NOT NULL DEFAULT false,
  genres text[] NOT NULL DEFAULT '{}'
    CHECK (genres <@ ARRAY['pop', 'hipHop', 'rnb', 'rock', 'electronic', 'jazz', 'folk']),
  services text[] NOT NULL
    CHECK (cardinality(services) > 0 AND services <@ ARRAY['mixing', 'mastering', 'vocals', 'beat']),
  price_from integer NOT NULL CHECK (price_from >= 0),
  capacity integer NOT NULL CHECK (capacity > 0),
  bio text NOT NULL DEFAULT ''
);

CREATE SEQUENCE request_numbers;

-- Zahtevi za saradnju. Pravila (dužina napomene, broj revizija, kapacitet) proverava server iz domenskog paketa;
-- baza čuva samo oblik podataka, da pravilo ne postoji dvaput.
CREATE TABLE requests (
  id text PRIMARY KEY DEFAULT 'r-' || nextval('request_numbers'),
  client_id text NOT NULL REFERENCES users (id),
  provider_id text NOT NULL REFERENCES providers (id),
  service text NOT NULL CHECK (service IN ('mixing', 'mastering', 'vocals', 'beat')),
  note text NOT NULL CHECK (char_length(note) > 0),
  status text NOT NULL
    CHECK (status IN ('sent', 'accepted', 'inProgress', 'delivered', 'completed', 'rejected', 'cancelled')),
  revisions integer NOT NULL DEFAULT 0 CHECK (revisions >= 0),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE INDEX requests_by_client ON requests (client_id);
CREATE INDEX requests_by_provider ON requests (provider_id, status);
CREATE INDEX requests_by_created ON requests (created_at DESC);

-- migrate:down
DROP TABLE requests;
DROP SEQUENCE request_numbers;
DROP TABLE providers;
DROP TABLE users;
